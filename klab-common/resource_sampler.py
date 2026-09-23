#!/usr/bin/env python3
"""1 回の実行が使った資源を、一定間隔で測って書き出す。

呼ぶのは klab-common/resource_sampler.sh で、そこから背景で起動される。
**処理スクリプトの側に足す行は無い**（run_status.sh が呼ぶため）。

  resource_sampler.py <log_dir> <root_pid> <interval_sec> <work_dir>

出力は 2 つ（役割が違うので両方要る）。

  resources.observed.tsv   時系列。いつ何が起きたかを人が追う
  resources.summary.json   要約。capacity が読む。**時系列から作る**（別に測らない）

測るのは <root_pid> の子孫だけである。cgroup を読めば楽だが、同じコンテナで
複数本走らせると合算しか返らず、1 本あたりが分からなくなる。

SIGTERM を受けたら要約を書いて終わる。**シグナルで死ぬときに書き切る**のは
run_status.sh と同じ考え方で、EXIT を当てにしない。
"""
import io
import json
import os
import signal
import subprocess
import sys
import time

CLK_TCK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
GIB = 1024.0 ** 3
MIB = 1024.0 ** 2

COLUMNS = ["at", "cpu_cores", "rss_gib", "read_mbps", "write_mbps",
           "disk_free_gib", "load1", "gpu_util_pct", "gpu_mem_gib", "gpu_procs"]


def read_stat(pid):
    """/proc/<pid>/stat から (ppid, utime+stime) を返す。読めなければ None。

    **comm はそのままでは割れない。**空白も括弧も入り得るので、最後の ')' で切る。
    """
    try:
        with io.open("/proc/%d/stat" % pid, encoding="utf-8", errors="replace") as f:
            raw = f.read()
    except (IOError, OSError):
        return None
    cut = raw.rfind(")")
    if cut < 0:
        return None
    rest = raw[cut + 2:].split()
    if len(rest) < 15:
        return None
    try:
        ppid = int(rest[1])              # 4 番目のフィールド
        utime = int(rest[11])            # 14
        stime = int(rest[12])            # 15
    except (ValueError, IndexError):
        return None
    return ppid, utime + stime


def read_rss(pid):
    try:
        with io.open("/proc/%d/statm" % pid, encoding="utf-8") as f:
            return int(f.read().split()[1]) * PAGE
    except (IOError, OSError, ValueError, IndexError):
        return 0


def read_io(pid):
    """読み書きのバイト数。**権限が無ければ 0 を返す**（他人のプロセスは測れない）。"""
    r = w = 0
    try:
        with io.open("/proc/%d/io" % pid, encoding="utf-8") as f:
            for line in f:
                if line.startswith("read_bytes:"):
                    r = int(line.split()[1])
                elif line.startswith("write_bytes:"):
                    w = int(line.split()[1])
    except (IOError, OSError, ValueError, IndexError):
        pass
    return r, w


def descendants(root):
    """root とその子孫の pid を返す。

    **1 周分の /proc を 1 回だけ読む。**親子関係を組み立ててから辿らないと、
    読んでいる間に木が変わって取りこぼす。
    """
    children = {}
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        pid = int(name)
        st = read_stat(pid)
        if st is None:
            continue
        children.setdefault(st[0], []).append(pid)
    out, stack = [], [root]
    while stack:
        pid = stack.pop()
        out.append(pid)
        stack.extend(children.get(pid, []))
    return out


def gpu_sample():
    """(利用率%, VRAM GiB, GPU を使っているプロセス数)。GPU が無ければ 3 つとも None。

    **プロセス単位の帰属は取れない。**nvidia-smi が返すのはホストの PID で、
    コンテナの PID 名前空間とは一致しない。だからデバイス単位で測り、
    「GPU を使っているプロセスが 1 つだけか」で自分のものと見なせるかを決める。
    """
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=10)
        if out.returncode != 0 or not out.stdout.strip():
            return None, None, None
        util = mem = 0.0
        for line in out.stdout.strip().splitlines():
            a, b = [x.strip() for x in line.split(",")[:2]]
            util = max(util, float(a))
            mem += float(b) / 1024.0
        apps = subprocess.run(
            ["nvidia-smi", "--query-compute-apps=pid", "--format=csv,noheader"],
            capture_output=True, text=True, timeout=10)
        n = len([x for x in apps.stdout.strip().splitlines() if x.strip()]) \
            if apps.returncode == 0 else 0
        return util, mem, n
    except (OSError, ValueError, subprocess.SubprocessError):
        return None, None, None


class Sampler(object):
    def __init__(self, log_dir, root, interval, work_dir):
        self.log_dir, self.root = log_dir, root
        self.interval, self.work_dir = interval, work_dir
        self.tsv = os.path.join(log_dir, "resources.observed.tsv")
        self.summary = os.path.join(log_dir, "resources.summary.json")
        # 終わったプロセスの分を持ち越す。**持ち越さないと、短命なプロセスが
        # 消えるたびに合計が減り、CPU も I/O も実際より少なく見える。**
        self.last = {}          # pid -> (cpu_ticks, read, write)
        self.retired = [0, 0, 0]
        self.prev = None        # (t, cpu_ticks, read, write)
        self.started = time.time()
        self.samples = 0
        self.peak = {"cpu": 0.0, "rss": 0.0, "read": 0.0, "write": 0.0,
                     "gpu_util": 0.0, "gpu_mem": 0.0}
        self.mean_cpu_num = 0.0
        self.gpu_seen = False
        self.gpu_available = None
        self.gpu_exclusive = True
        self.stop = False

    def totals(self):
        alive_cpu = alive_r = alive_w = rss = 0
        seen = set()
        for pid in descendants(self.root):
            st = read_stat(pid)
            if st is None:
                continue
            seen.add(pid)
            r, w = read_io(pid)
            alive_cpu += st[1]
            alive_r += r
            alive_w += w
            rss += read_rss(pid)
            self.last[pid] = (st[1], r, w)
        for pid in [p for p in self.last if p not in seen]:
            c, r, w = self.last.pop(pid)
            self.retired[0] += c
            self.retired[1] += r
            self.retired[2] += w
        return (alive_cpu + self.retired[0], alive_r + self.retired[1],
                alive_w + self.retired[2], rss)

    def sample(self):
        now = time.time()
        cpu, rd, wr, rss = self.totals()
        util, gmem, gprocs = gpu_sample()
        if self.gpu_available is None:
            self.gpu_available = util is not None
        row = {"at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
               "rss_gib": "%.3f" % (rss / GIB),
               "disk_free_gib": "%.1f" % (self._free() / GIB),
               "load1": open("/proc/loadavg").read().split()[0]}
        if self.prev is None:
            row.update({"cpu_cores": "-", "read_mbps": "-", "write_mbps": "-"})
        else:
            dt = max(now - self.prev[0], 1e-6)
            cores = (cpu - self.prev[1]) / CLK_TCK / dt
            rmb = (rd - self.prev[2]) / dt / MIB
            wmb = (wr - self.prev[3]) / dt / MIB
            row.update({"cpu_cores": "%.2f" % cores,
                        "read_mbps": "%.1f" % rmb, "write_mbps": "%.1f" % wmb})
            self.peak["cpu"] = max(self.peak["cpu"], cores)
            self.peak["read"] = max(self.peak["read"], rmb)
            self.peak["write"] = max(self.peak["write"], wmb)
            self.mean_cpu_num += cores * dt
        self.peak["rss"] = max(self.peak["rss"], rss / GIB)
        # **GPU が無い環境では - を書く。**0 と書くと「GPU が無い」と
        # 「在るが使っていない」が読み分けられなくなる。
        if util is None:
            row.update({"gpu_util_pct": "-", "gpu_mem_gib": "-", "gpu_procs": "-"})
        else:
            row.update({"gpu_util_pct": "%.0f" % util,
                        "gpu_mem_gib": "%.2f" % gmem, "gpu_procs": str(gprocs)})
            self.peak["gpu_util"] = max(self.peak["gpu_util"], util)
            self.peak["gpu_mem"] = max(self.peak["gpu_mem"], gmem)
            if gprocs and gprocs >= 1:
                self.gpu_seen = True
                if gprocs > 1:
                    self.gpu_exclusive = False
        self.prev = (now, cpu, rd, wr)
        self.samples += 1
        self._append(row)
        self.final = (cpu, rd, wr)

    def _free(self):
        try:
            st = os.statvfs(self.work_dir)
            return st.f_bavail * st.f_frsize
        except OSError:
            return 0

    def _append(self, row):
        new = not os.path.exists(self.tsv)
        with io.open(self.tsv, "a", encoding="utf-8") as f:
            if new:
                f.write("\t".join(COLUMNS) + "\n")
            f.write("\t".join(str(row.get(c, "-")) for c in COLUMNS) + "\n")

    def write_summary(self):
        dur = time.time() - self.started
        cpu, rd, wr = getattr(self, "final", (0, 0, 0))
        d = {
            "schemaVersion": 1,
            "measured": True,
            "rootPid": self.root,
            "durationSeconds": round(dur, 1),
            "samples": self.samples,
            "intervalSeconds": self.interval,
            "cpuCoresMean": round(self.mean_cpu_num / dur, 3) if dur > 0 else None,
            "cpuCoresPeak": round(self.peak["cpu"], 3),
            "rssGiBPeak": round(self.peak["rss"], 3),
            "readGiBTotal": round(rd / GIB, 3),
            "writeGiBTotal": round(wr / GIB, 3),
            "readMBpsPeak": round(self.peak["read"], 1),
            "writeMBpsPeak": round(self.peak["write"], 1),
            "gpuAvailable": self.gpu_available,
            "gpuUsed": self.gpu_seen if self.gpu_available else False,
            "gpuUtilPeak": round(self.peak["gpu_util"], 1) if self.gpu_seen else None,
            "gpuMemGiBPeak": round(self.peak["gpu_mem"], 3) if self.gpu_seen else None,
            "gpuExclusive": self.gpu_exclusive if self.gpu_seen else None,
            "note": ("GPU がこの環境に無いので gpu_* は - である。"
                     if not self.gpu_available else
                     "GPU はデバイス単位で測っている。gpuExclusive が false のときは"
                     "他のプロセスと混ざっているので、見積もりに使わないこと。"),
        }
        tmp = self.summary + ".tmp"
        io.open(tmp, "w", encoding="utf-8").write(
            json.dumps(d, ensure_ascii=False, indent=2) + "\n")
        os.replace(tmp, self.summary)

    def run(self):
        def onterm(_sig, _frm):
            self.stop = True
        signal.signal(signal.SIGTERM, onterm)
        signal.signal(signal.SIGINT, onterm)
        self.sample()
        while not self.stop:
            for _ in range(int(self.interval * 10)):
                if self.stop:
                    break
                time.sleep(0.1)
            # **止められても最後に 1 回測る。**そうしないと最後の区間が落ちる。
            try:
                self.sample()
            except Exception:
                break
            if not os.path.isdir("/proc/%d" % self.root):
                break            # 本体が終わっていれば測る相手が居ない
        self.write_summary()


def main():
    if len(sys.argv) < 5:
        sys.stderr.write(__doc__)
        return 2
    log_dir, root, interval, work_dir = (sys.argv[1], int(sys.argv[2]),
                                         float(sys.argv[3]), sys.argv[4])
    Sampler(log_dir, root, interval, work_dir).run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
