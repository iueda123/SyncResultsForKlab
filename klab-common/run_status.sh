#!/bin/bash
#
# klab-common/run_status.sh
#
# 説明:
#   1回の処理実行（1 PROC_ID）の開始情報と終了結果を、機械可読な JSON として
#   PROC_ID ディレクトリ直下に残すための共通ライブラリ。
#
#     logs/<dataset_id>/<subject_id>/<PROC_ID>/
#     ├── <timestamp>_<script>.txt   … 従来の人間向けログ
#     ├── run.started.json           … 起動直後に書かれる
#     └── run.status.json            … 終了時に EXIT トラップで必ず書かれる
#
#   ProcCompletionChecker の Batch Progress Checker は run.status.json を読んで
#   1プロセスずつの完了状況を判定する。これが無い場合はログ本文の文言マッチへ
#   フォールバックするため、本ライブラリの導入前に生成されたログも従来どおり
#   扱える。
#
# 使い方:
#   source "$(dirname "${_this_script_path}")/klab-common/run_status.sh"
#   klabRunStatusInit \
#       --proc-type="DMriPreproc" \
#       --script="${_script_name}" \
#       --dataset-id="${dataset_id}" \
#       --subject-id="${subject_id}" \
#       --proc-id="${PROC_ID}" \
#       --log-dir="${log_dir}" \
#       --log-file="${log_file_path}"
#
#   処理の途中で以下を呼ぶと、終了時の JSON に反映される。
#     klabRunStatusSetLastStep "pushDerivativesToShareServer.sh"
#     klabRunStatusSetOutcome NOTHING_TO_DO "同期対象が1つも見つからなかった"
#
# 設計上の約束:
#   * 本ライブラリのどの関数も、失敗して呼び出し元の処理を止めてはならない。
#     すべての関数は 0 を返す（set -e 下で source されることを前提とする）。
#   * SIGKILL は捕捉できないため run.status.json が残らないことがある。
#     その場合に備え run.started.json に pid と host を記録しておき、
#     参照側は「開始済みだが終了記録なし」を検出できるようにする。
#
# このファイルは全処理リポジトリに同一内容で配置される。将来的に共通リポジトリ
# へ切り出す前提のため、リポジトリ固有の値をこのファイルへ書き込まないこと。
#

KLAB_RUN_STATUS_SCHEMA_VERSION=1

KLAB_RUN_STATUS_DIR=""
KLAB_RUN_STATUS_PROC_TYPE=""
KLAB_RUN_STATUS_SCRIPT=""
KLAB_RUN_STATUS_DATASET_ID=""
KLAB_RUN_STATUS_SUBJECT_ID=""
KLAB_RUN_STATUS_PROC_ID=""
KLAB_RUN_STATUS_LOG_FILE=""
KLAB_RUN_STATUS_STARTED_AT=""
KLAB_RUN_STATUS_STARTED_EPOCH=""
KLAB_RUN_STATUS_LAST_STEP=""
KLAB_RUN_STATUS_OUTCOME_OVERRIDE=""
KLAB_RUN_STATUS_MESSAGE=""
KLAB_RUN_STATUS_ACTIVE="false"

#
# 説明:
#   JSON 文字列値として安全な形へエスケープする
#
# 入力:
#   エスケープ対象の文字列
#
_klabRunStatusEscapeJson(){
    local _raw="$1"
    local _out=""
    local _index
    local _char
    for (( _index = 0; _index < ${#_raw}; _index++ )); do
        _char="${_raw:_index:1}"
        case "${_char}" in
            '"')  _out+='\"' ;;
            '\')  _out+='\\' ;;
            $'\n') _out+='\n' ;;
            $'\r') _out+='\r' ;;
            $'\t') _out+='\t' ;;
            *)
                # 制御文字は落とす（JSON では生のまま置けないため）
                if [[ "${_char}" < ' ' ]]; then
                    _out+=' '
                else
                    _out+="${_char}"
                fi
                ;;
        esac
    done
    printf '%s' "${_out}"
}

#
# 説明:
#   ISO 8601（タイムゾーン付き）の現在時刻を返す
#
_klabRunStatusNow(){
    date +%Y-%m-%dT%H:%M:%S%:z 2>/dev/null || date +%Y-%m-%dT%H:%M:%S
}

#
# 説明:
#   run status の記録を開始する。run.started.json を書き、
#   終了時に run.status.json を書く EXIT トラップを仕掛ける。
#
# 入力（すべて --key=value 形式。順不同）:
#   --proc-type   ProcCompletionChecker の Proc Type 識別子
#   --script      メインスクリプトのファイル名
#   --dataset-id  ログ整理用のデータセットID
#   --subject-id  被験者ID（全被験者モードでは all-subjects）
#   --proc-id     PROC_ID（ログディレクトリ名）
#   --log-dir     PROC_ID ディレクトリの絶対パス
#   --log-file    メインログファイルの絶対パス
#
klabRunStatusInit(){

    local _argument
    for _argument in "$@"; do
        case "${_argument}" in
            --proc-type=*)  KLAB_RUN_STATUS_PROC_TYPE="${_argument#*=}" ;;
            --script=*)     KLAB_RUN_STATUS_SCRIPT="${_argument#*=}" ;;
            --dataset-id=*) KLAB_RUN_STATUS_DATASET_ID="${_argument#*=}" ;;
            --subject-id=*) KLAB_RUN_STATUS_SUBJECT_ID="${_argument#*=}" ;;
            --proc-id=*)    KLAB_RUN_STATUS_PROC_ID="${_argument#*=}" ;;
            --log-dir=*)    KLAB_RUN_STATUS_DIR="${_argument#*=}" ;;
            --log-file=*)   KLAB_RUN_STATUS_LOG_FILE="${_argument#*=}" ;;
            *) ;;
        esac
    done

    if [[ -z "${KLAB_RUN_STATUS_DIR}" || ! -d "${KLAB_RUN_STATUS_DIR}" ]]; then
        # 記録先が無い場合は黙って無効化する。処理本体は止めない。
        KLAB_RUN_STATUS_ACTIVE="false"
        return 0
    fi

    KLAB_RUN_STATUS_STARTED_AT="$(_klabRunStatusNow)"
    KLAB_RUN_STATUS_STARTED_EPOCH="$(date +%s 2>/dev/null || echo 0)"
    KLAB_RUN_STATUS_LAST_STEP=""
    KLAB_RUN_STATUS_OUTCOME_OVERRIDE=""
    KLAB_RUN_STATUS_MESSAGE=""
    KLAB_RUN_STATUS_ACTIVE="true"

    {
        printf '{\n'
        printf '  "schemaVersion": %s,\n' "${KLAB_RUN_STATUS_SCHEMA_VERSION}"
        printf '  "procType": "%s",\n'    "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_PROC_TYPE}")"
        printf '  "script": "%s",\n'      "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_SCRIPT}")"
        printf '  "datasetId": "%s",\n'   "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_DATASET_ID}")"
        printf '  "subjectId": "%s",\n'   "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_SUBJECT_ID}")"
        printf '  "procId": "%s",\n'      "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_PROC_ID}")"
        printf '  "pid": %s,\n'           "$$"
        printf '  "host": "%s",\n'        "$(_klabRunStatusEscapeJson "$(hostname 2>/dev/null || echo unknown)")"
        printf '  "user": "%s",\n'        "$(_klabRunStatusEscapeJson "$(id -un 2>/dev/null || echo unknown)")"
        printf '  "logFile": "%s",\n'     "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_LOG_FILE}")"
        printf '  "startedAt": "%s",\n'   "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_STARTED_AT}")"
        printf '  "startedAtEpoch": %s\n' "${KLAB_RUN_STATUS_STARTED_EPOCH}"
        printf '}\n'
    } > "${KLAB_RUN_STATUS_DIR}/run.started.json" 2>/dev/null || true

    trap '_klabRunStatusFinalize "$?"' EXIT

    return 0
}

#
# 説明:
#   終了結果を明示的に指定する。指定しない場合は終了コードから決まる。
#
# 入力:
#   $1 SUCCESS | FAILED | NOTHING_TO_DO | ABORTED
#   $2 補足メッセージ（省略可）
#
klabRunStatusSetOutcome(){
    KLAB_RUN_STATUS_OUTCOME_OVERRIDE="${1:-}"
    if [[ $# -ge 2 ]]; then
        KLAB_RUN_STATUS_MESSAGE="${2}"
    fi
    return 0
}

#
# 説明:
#   到達したステップ名を記録する。どこまで進んだかの把握に使う。
#
# 入力:
#   $1 ステップ名（サブスクリプト名など）
#
klabRunStatusSetLastStep(){
    KLAB_RUN_STATUS_LAST_STEP="${1:-}"
    return 0
}

#
# 説明:
#   補足メッセージを記録する。
#
# 入力:
#   $1 メッセージ
#
klabRunStatusSetMessage(){
    KLAB_RUN_STATUS_MESSAGE="${1:-}"
    return 0
}

#
# 説明:
#   klabRunStatusSetOutcome で指定した結果と補足メッセージを取り消し、
#   終了コードによる判定へ戻す。
#
#   繰り返し処理の途中で 1 件だけ NOTHING_TO_DO になったようなとき、その指定が
#   実行全体の結果として残ってしまうのを防ぐために、正常終了へ到達した時点で呼ぶ。
#
klabRunStatusClearOutcome(){
    KLAB_RUN_STATUS_OUTCOME_OVERRIDE=""
    KLAB_RUN_STATUS_MESSAGE=""
    return 0
}

#
# 説明:
#   シグナル受信時に ABORTED として run.status.json を即座に書き出す。
#   呼び出し側のシグナルハンドラから、シグナルを再送出する前に呼ぶこと。
#
#   シグナルハンドラが `trap - SIG; kill -s SIG $$` で自身を殺す作法を取ると、
#   シェルはシグナルによって終了するため EXIT トラップが走らない（実測で確認済み）。
#   そのため終了を待たずにここで書き切る。
#
# 入力:
#   $1 シグナル名
#
klabRunStatusMarkAborted(){
    local _signal="${1:-UNKNOWN}"
    KLAB_RUN_STATUS_OUTCOME_OVERRIDE="ABORTED"
    KLAB_RUN_STATUS_MESSAGE="シグナル ${_signal} を受信して中断した。"

    local _exit_code=1
    case "${_signal}" in
        INT)  _exit_code=130 ;;
        TERM) _exit_code=143 ;;
        HUP)  _exit_code=129 ;;
    esac
    _klabRunStatusFinalize "${_exit_code}"

    return 0
}

#
# 説明:
#   EXIT トラップから呼ばれ、run.status.json を書く。
#
# 入力:
#   $1 終了コード
#
_klabRunStatusFinalize(){

    local _exit_code="${1:-0}"

    # ここから先で失敗しても終了処理を止めない
    set +e

    if [[ "${KLAB_RUN_STATUS_ACTIVE}" != "true" ]]; then
        return 0
    fi
    KLAB_RUN_STATUS_ACTIVE="false"

    local _outcome
    if [[ -n "${KLAB_RUN_STATUS_OUTCOME_OVERRIDE}" ]]; then
        _outcome="${KLAB_RUN_STATUS_OUTCOME_OVERRIDE}"
    elif [[ "${_exit_code}" -eq 0 ]]; then
        _outcome="SUCCESS"
    else
        _outcome="FAILED"
    fi

    local _finished_epoch
    _finished_epoch="$(date +%s 2>/dev/null || echo 0)"
    local _duration=0
    if [[ "${KLAB_RUN_STATUS_STARTED_EPOCH}" =~ ^[0-9]+$ && "${_finished_epoch}" =~ ^[0-9]+$ ]]; then
        _duration=$(( _finished_epoch - KLAB_RUN_STATUS_STARTED_EPOCH ))
    fi

    {
        printf '{\n'
        printf '  "schemaVersion": %s,\n'   "${KLAB_RUN_STATUS_SCHEMA_VERSION}"
        printf '  "procType": "%s",\n'      "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_PROC_TYPE}")"
        printf '  "script": "%s",\n'        "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_SCRIPT}")"
        printf '  "datasetId": "%s",\n'     "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_DATASET_ID}")"
        printf '  "subjectId": "%s",\n'     "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_SUBJECT_ID}")"
        printf '  "procId": "%s",\n'        "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_PROC_ID}")"
        printf '  "pid": %s,\n'             "$$"
        printf '  "startedAt": "%s",\n'     "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_STARTED_AT}")"
        printf '  "finishedAt": "%s",\n'    "$(_klabRunStatusEscapeJson "$(_klabRunStatusNow)")"
        printf '  "durationSeconds": %s,\n' "${_duration}"
        printf '  "exitCode": %s,\n'        "${_exit_code}"
        printf '  "outcome": "%s",\n'       "$(_klabRunStatusEscapeJson "${_outcome}")"
        printf '  "lastStep": "%s",\n'      "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_LAST_STEP}")"
        printf '  "message": "%s"\n'        "$(_klabRunStatusEscapeJson "${KLAB_RUN_STATUS_MESSAGE}")"
        printf '}\n'
    } > "${KLAB_RUN_STATUS_DIR}/run.status.json" 2>/dev/null

    return 0
}
