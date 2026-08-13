# klab-common

Klab の処理スクリプト各リポジトリで共通に使うシェル関数を置くディレクトリ。

**このディレクトリの中身は全リポジトリで同一である。** 片方だけを直さないこと。
将来的には共通リポジトリ（submodule）へ切り出す前提で、リポジトリ固有の値を
ここに書き込まないようにしている。

| ファイル | 内容 |
|:---|:---|
| `run_status.sh` | 1回の処理実行の開始情報と終了結果を機械可読な JSON として残す |

---

## run_status.sh — 実行結果コントラクト

各処理スクリプトは、実行のたびに `PROC_ID` ディレクトリを作り、その中に人間向けの
ログを出力している。ここに 2 つの JSON を追加で残す。

```
logs/<dataset_id>/<subject_id>/<PROC_ID>/
├── <timestamp>_<script>.txt   … 従来の人間向けログ
├── run.started.json           … 起動直後に書かれる
└── run.status.json            … 終了時に書かれる
```

### なぜ必要か

これまで「その処理が完了したのか、失敗したのか、まだ動いているのか」は、ログ本文の
末尾の文言を見るしかなかった。しかしその文言はリポジトリごとに違い、さらに次の問題が
あった。

* 完了行が素の `echo` で書かれているとログファイルに残らない（`logger.sh` の
  `show_msg` を通らないため）。実際 `Aggregate_dMRI_Features_on_MMP1` の完了行は
  どのログにも残っていなかった。
* 全スクリプトが `set -e` を宣言しているため、「処理対象が無かった」という正常な
  結末でも早期 `return 1` でシェルが終了し、完了行に到達しない。異常終了と区別
  できなかった。

JSON を1つ読めば済むようにすることで、参照側（ProcCompletionChecker の
Batch Progress Checker）が文言解析に依存しなくなる。

### run.status.json

```json
{
  "schemaVersion": 1,
  "procType": "DMriPreproc",
  "script": "run_dmri_preproc_pipelines_for_klab.sh",
  "datasetId": "2_11",
  "subjectId": "sub-K2002191800",
  "procId": "20260807-1005-hudcB",
  "pid": 433873,
  "startedAt": "2026-08-07T10:05:35+09:00",
  "finishedAt": "2026-08-07T11:50:34+09:00",
  "durationSeconds": 6299,
  "exitCode": 0,
  "outcome": "SUCCESS",
  "lastStep": "2026-08-07_11-50-34_pushDerivativesToShareServer.sh.txt",
  "message": ""
}
```

`outcome` の意味:

| 値 | 意味 |
|:---|:---|
| `SUCCESS` | 正常終了した |
| `FAILED` | 異常終了した（終了コードが 0 以外） |
| `NOTHING_TO_DO` | 正常に動いたが、処理すべき対象が無かった |
| `ABORTED` | TERM / INT / HUP を受けて中断した |

`SIGKILL` は捕捉できないため、強制終了された場合は `run.status.json` が残らない。
その場合は `run.started.json` だけが存在する状態になり、参照側は「開始したが
終了記録が無い」として扱える。`run.started.json` には `pid` と `host` も記録して
あるので、必要なら生存確認に使える。

### 組み込み方

ログ設定（`setLogFilePath`）の直後に以下を置く。

```bash
source "$(dirname ${this_script_path})/klab-common/run_status.sh"
klabRunStatusInit \
    --proc-type="DMriPreproc" \
    --script="${_script_name}" \
    --dataset-id="${dataset_id}" \
    --subject-id="${subject_id}" \
    --proc-id="${PROC_ID}" \
    --log-dir="${log_dir}" \
    --log-file="${log_file_path}"
klabRunStatusOnSignal(){
    local _signal="$1"
    set +e
    klabRunStatusMarkAborted "${_signal}"
    trap - "${_signal}"
    kill -s "${_signal}" "$$"
}
trap 'klabRunStatusOnSignal TERM' TERM
trap 'klabRunStatusOnSignal INT' INT
trap 'klabRunStatusOnSignal HUP' HUP
```

既にシグナルハンドラを持つスクリプト（`Aggregate_dMRI_Features_on_MMP1`）では、
上の `klabRunStatusOnSignal` は定義せず、既存のハンドラの中で
`klabRunStatusMarkAborted "${_signal}"` を呼ぶ。

### 提供する関数

| 関数 | 用途 |
|:---|:---|
| `klabRunStatusInit` | 記録を開始する。`run.started.json` を書き、EXIT トラップを仕掛ける |
| `klabRunStatusSetOutcome <outcome> [message]` | 結果を明示する。`NOTHING_TO_DO` を返す経路で使う |
| `klabRunStatusSetLastStep <step>` | 到達ステップを記録する |
| `klabRunStatusSetMessage <message>` | 補足メッセージを記録する |
| `klabRunStatusMarkAborted <signal>` | 中断として `run.status.json` を即座に書く |

到達ステップは `logger.sh` の `setLogFilePath` にフックを入れてあるため、
各サブスクリプトが自分のログファイルを設定するたびに自動で更新される。
個々のサブスクリプトを改修する必要はない。

### 設計上の約束

* どの関数も失敗して呼び出し元を止めない。すべて 0 を返す。
* 記録先ディレクトリが無い場合は黙って無効化し、処理本体には影響させない。
* シグナル受信時は EXIT トラップを当てにしない。シグナルで終了するシェルでは
  EXIT トラップが走らないことを実測で確認している。
