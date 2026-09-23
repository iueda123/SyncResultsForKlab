# klab-common/resource_sampler.sh — 1 回の実行の資源消費を測る（起動と停止だけ）。
#
# **処理スクリプトの側に足す行は無い。**run_status.sh の
# klabRunStatusInit / klabRunStatusFinish から呼ばれる。既にすべての処理スクリプトが
# run-status 契約を通るので、これを入れた時点で全部が計測付きになる。
#
# 測る中身は resource_sampler.py に在る。ここは背景で起こして止めるだけである。

KLAB_SAMPLER_PID=""
KLAB_SAMPLER_DIR=""

# 間隔と作業域は呼ぶ側が変えられる。既定は 30 秒。
KLAB_RESOURCE_INTERVAL="${KLAB_RESOURCE_INTERVAL:-30}"
KLAB_RESOURCE_WORK_DIR="${KLAB_RESOURCE_WORK_DIR:-}"

# 測れないときは**黙って済ませない。**測っていないことを記録に残す。
_klabResourceSamplerSkip() {
    local dir="$1" why="$2"
    cat > "${dir}/resources.summary.json" <<JSON
{
  "schemaVersion": 1,
  "measured": false,
  "reason": "${why}"
}
JSON
}

# klabRunStatusInit から呼ぶ。根は **run_status.sh を source した本体の PID**（$$）。
_klabResourceSamplerStart() {
    local dir="${1:?log_dir が要ります}"
    local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local py="${here}/resource_sampler.py"
    KLAB_SAMPLER_DIR="$dir"

    if ! command -v python3 >/dev/null 2>&1; then
        _klabResourceSamplerSkip "$dir" "python3 がありません"
        return 0
    fi
    if [[ ! -f "$py" ]]; then
        _klabResourceSamplerSkip "$dir" "resource_sampler.py がありません: ${py}"
        return 0
    fi

    # 作業域の空きを見る先。渡されなければログの置き場で代用する。
    local work="${KLAB_RESOURCE_WORK_DIR:-$dir}"
    # **標準入出力を切り離す。**本体が exec > >(tee ...) で標準出力を差し替えるので、
    # 繋いだままだと採取の出力がログに混ざり、本体の終了も待たせてしまう。
    python3 "$py" "$dir" "$$" "$KLAB_RESOURCE_INTERVAL" "$work" \
        </dev/null >/dev/null 2>"${dir}/resources.sampler.err" &
    KLAB_SAMPLER_PID=$!
    # **ジョブ表から外す（disown）。**外さないと、本体が引数なしの `wait` を呼んだ
    # ときに**採取の終了まで永久に待つ**（採取は止められるまで終わらない）。
    # 処理スクリプトが子プロセスを並べて `wait` で揃えるのはごく普通の書き方なので、
    # ここで塞いでおかないと、使う側が原因の分からない固まり方をする。実際に踏んだ。
    disown "$KLAB_SAMPLER_PID" 2>/dev/null || true
    return 0
}

# klabRunStatusFinish / MarkAborted から呼ぶ。
#
# **要約を書き終わるまで待つ。**待たずに本体が終わると、要約が無いまま残る
# （測ったのに測っていないように見える、いちばん質の悪い状態）。
_klabResourceSamplerStop() {
    [[ -n "$KLAB_SAMPLER_PID" ]] || return 0
    kill -TERM "$KLAB_SAMPLER_PID" 2>/dev/null || true
    local i
    for ((i = 0; i < 100; i++)); do
        kill -0 "$KLAB_SAMPLER_PID" 2>/dev/null || break
        sleep 0.1
    done
    kill -0 "$KLAB_SAMPLER_PID" 2>/dev/null && kill -KILL "$KLAB_SAMPLER_PID" 2>/dev/null
    # disown してあるので `wait` は使えない（ジョブ表に無い）。上の kill -0 で待つ。
    KLAB_SAMPLER_PID=""
    # 空のエラーファイルは残さない（在ると「何かあった」と読ませる）。
    [[ -s "${KLAB_SAMPLER_DIR}/resources.sampler.err" ]] \
        || rm -f "${KLAB_SAMPLER_DIR}/resources.sampler.err"
    # **要約が無いまま終わらせない。**すぐ落ちた実行では、採取が signal handler を
    # 構える前に TERM が届き、1 行も残らずに消えることがある（入力が無くて 0 秒で
    # 落ちたときに実際に踏んだ）。そのままだと「測っていない」のか「測ったが空」
    # なのかを後から読み分けられない。
    if [[ ! -f "${KLAB_SAMPLER_DIR}/resources.summary.json" ]]; then
        _klabResourceSamplerSkip "$KLAB_SAMPLER_DIR" \
            "実行が短すぎて標本が取れませんでした（採取の起動より先に終了）"
    fi
    return 0
}
