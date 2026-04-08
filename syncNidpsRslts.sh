#!/bin/bash

set -e

_this_script_path="$(readlink -f "${BASH_SOURCE[0]}")"
_script_name=$(basename "${_this_script_path}")

function sync_nidps_results() {

    function usage() {
        echo ""
        echo "=================================================================="
        echo ""
        echo "${_script_name}"
        echo ""
        echo "version: 20260408"
        echo ""
        echo "USAGE:"
        echo "    ${_script_name} \\"
        echo "        [--subject-id=<SUBJECT_ID>] \\"
        echo "        --drv-of-subjects-on-proc=<PROCESSED_FOLDER_PATH> \\"
        echo "        --drv-of-subjects-on-share=<SHARE_FOLDER_PATH> \\"
        echo "        [--mode=<NIDPS|DIFFUSION|LGI>] \\"
        echo "        [--keep-structure] \\"
        echo "        [--run] \\"
        echo "        [--help]"
        echo ""
        echo "DESCRIPTION:"
        echo "    各被験者フォルダ配下の対象データを処理サーバーから共有サーバーに同期するスクリプトです。"
        echo "    デフォルトでは dry-run で動作し、--run オプションで実際の同期を実行します。"
        echo ""
        echo "REQUIRED OPTIONS:"
        echo "    --drv-of-subjects-on-proc      処理サーバー上の SubjectsRoot パス（同期元）"
        echo "    --drv-of-subjects-on-share     共有サーバー上の SubjectsRoot パス（同期先）"
        echo ""
        echo "OPTIONAL OPTIONS:"
        echo "    --subject-id                   被験者ID。指定しない場合は全被験者を処理"
        echo "    --mode                         同期モードを指定"
        echo "                                   NIDPS: \${SUBJECT_ID}/NIDPs/ を同期"
        echo "                                   DIFFUSION: 指定のDiffusion関連データを同期"
        echo "                                   LGI: 指定のLGI関連ファイルを同期"
        echo "    --keep-structure               同期先でも --drv-of-subjects-on-proc 以下の構造を保持"
        echo "    --run                          実際の同期を実行（省略時は dry-run）"
        echo "    --help, -h                     このヘルプを表示"
        echo ""
        echo "SYNC TARGET:"
        echo "    * --mode=NIDPS"
        echo "      \${SUBJECT_ID}/NIDPs/"
        echo "    * --mode=DIFFUSION"
        echo "      \${SUBJECT_ID}/T1w/Diffusion/"
        echo "      \${SUBJECT_ID}/Diffusion/"
        echo "      \${SUBJECT_ID}/T1w/T1w_acpc_dc_restore_1.50.nii.gz"
        echo "    * --mode=LGI"
        echo "      \${SUBJECT_ID}/NIDPs/\${SUBJECT_ID}_LGI_MSMSulc.csv"
        echo "      \${SUBJECT_ID}/NIDPs/\${SUBJECT_ID}_LGI_MSMAll.csv"
        echo "      \${SUBJECT_ID}/T1w/\${SUBJECT_ID}/stats/lh.mean.pial_lgi.stats"
        echo "      \${SUBJECT_ID}/T1w/\${SUBJECT_ID}/stats/rh.mean.pial_lgi.stats"
        echo "      \${SUBJECT_ID}/T1w/\${SUBJECT_ID}/stats/lh.aparc.pial_lgi.stats"
        echo "      \${SUBJECT_ID}/T1w/\${SUBJECT_ID}/stats/rh.aparc.pial_lgi.stats"
        echo ""
        echo "EXAMPLES:"
        echo "    ${_script_name} \\"
        echo "        --subject-id=sub-K2009231730 \\"
        echo "        --drv-of-subjects-on-proc=/mnt/data2/iueda/5_18/derivatives/HCPpipeline \\"
        echo "        --drv-of-subjects-on-share=/mnt/qnapdata2/mri2024/mri4/ext5_18"
        echo ""
        echo "    ${_script_name} \\"
        echo "        --drv-of-subjects-on-proc=/mnt/data2/iueda/5_18/derivatives/HCPpipeline \\"
        echo "        --drv-of-subjects-on-share=/mnt/qnapdata2/mri2024/mri4/ext5_18 \\"
        echo "        --mode=DIFFUSION \\"
        echo "        --run"
        echo ""
        echo "NOTE:"
        echo " * rsync を使うため増分同期です"
        echo " * 同期対象が存在しない被験者はスキップします"
        echo "=================================================================="
        echo ""
        exit 0
    }

    function get_batch_options() {
        local _arguments=("$@")

        run_mode="false"
        mode="NIDPS"

        unset help
        unset subject_id
        unset drv_of_subjects_on_proc
        unset drv_of_subjects_on_share
        unset keep_structure

        local _index=0
        local _num_args=${#_arguments[@]}
        local _argument

        while [ ${_index} -lt ${_num_args} ]; do
            _argument=${_arguments[_index]}

            case ${_argument} in
                --help|-h)
                    help="true"
                    ;;
                --subject-id=*)
                    subject_id=${_argument#*=}
                    ;;
                --mode=*)
                    mode=${_argument#*=}
                    ;;
                --drv-of-subjects-on-proc=*)
                    drv_of_subjects_on_proc=${_argument#*=}
                    ;;
                --drv-of-subjects-on-share=*)
                    drv_of_subjects_on_share=${_argument#*=}
                    ;;
                --keep-structure)
                    keep_structure="true"
                    ;;
                --run)
                    run_mode="true"
                    ;;
                *)
                    echo ""
                    echo "エラー: 認識されないオプション: ${_argument}"
                    echo ""
                    usage
                    exit 1
                    ;;
            esac

            _index=$(( _index + 1 ))
        done
    }

    function build_dest_root() {
        local _drv_of_subjects_on_proc=$1
        local _drv_of_subjects_on_share=$2

        if [[ "${keep_structure}" == "true" ]]; then
            local _proc_subpath
            _proc_subpath=$(echo "${_drv_of_subjects_on_proc}" | sed 's#^/mnt/[^/]*/[^/]*/##')

            if [[ -n "${_proc_subpath}" && "${_proc_subpath}" != "${_drv_of_subjects_on_proc}" ]]; then
                echo "${_drv_of_subjects_on_share}/${_proc_subpath}"
            else
                echo "${_drv_of_subjects_on_share}"
            fi
        else
            echo "${_drv_of_subjects_on_share}"
        fi
    }

    function run_rsync() {
        local _src=$1
        local _dst=$2
        local _run_mode=$3
        local _is_dir=$4

        mkdir -p "$(dirname "${_dst}")"

        if [ "${_run_mode}" == "true" ]; then
            echo "rsync 実行中（actual-run）..."
            if [ "${_is_dir}" == "true" ]; then
                rsync -avhu "${_src}/" "${_dst}/"
            else
                rsync -avhu "${_src}" "${_dst}"
            fi
        else
            echo "rsync 実行中（dry-run）..."
            if [ "${_is_dir}" == "true" ]; then
                rsync -avhun "${_src}/" "${_dst}/"
            else
                rsync -avhun "${_src}" "${_dst}"
            fi
        fi
    }

    function sync_nidps_mode() {
        local _subject_id=$1
        local _drv_of_subjects_on_proc=$2
        local _dest_root=$3
        local _run_mode=$4

        local _subject_src="${_drv_of_subjects_on_proc}/${_subject_id}"
        local _src_nidps="${_subject_src}/NIDPs"
        local _subject_dest="${_dest_root}/${_subject_id}"
        local _dest_nidps="${_subject_dest}/NIDPs"

        echo ""
        echo "=========================================="
        echo "被験者ID: ${_subject_id}"
        echo "同期元: ${_src_nidps}"
        echo "同期先: ${_dest_nidps}"
        echo "=========================================="
        echo ""

        if [ ! -d "${_subject_src}" ]; then
            echo "警告: 被験者ディレクトリが見つかりません: ${_subject_src}"
            echo "スキップします。"
            echo ""
            return 1
        fi

        if [ ! -d "${_src_nidps}" ]; then
            echo "警告: NIDPs ディレクトリが見つかりません: ${_src_nidps}"
            echo "スキップします。"
            echo ""
            return 1
        fi

        run_rsync "${_src_nidps}" "${_dest_nidps}" "${_run_mode}" "true"

        echo "同期完了: ${_subject_id}"
        echo ""
        return 0
    }

    function sync_diffusion_mode() {
        local _subject_id=$1
        local _drv_of_subjects_on_proc=$2
        local _dest_root=$3
        local _run_mode=$4

        local _subject_src="${_drv_of_subjects_on_proc}/${_subject_id}"
        local _subject_dest="${_dest_root}/${_subject_id}"
        local _found_any="false"

        echo ""
        echo "=========================================="
        echo "被験者ID: ${_subject_id}"
        echo "モード: DIFFUSION"
        echo "同期元: ${_subject_src}"
        echo "同期先: ${_subject_dest}"
        echo "=========================================="
        echo ""

        if [ ! -d "${_subject_src}" ]; then
            echo "警告: 被験者ディレクトリが見つかりません: ${_subject_src}"
            echo "スキップします。"
            echo ""
            return 1
        fi

        local _src
        local _dst

        _src="${_subject_src}/T1w/Diffusion"
        _dst="${_subject_dest}/T1w/Diffusion"
        if [ -d "${_src}" ]; then
            echo "同期対象: ${_src}"
            run_rsync "${_src}" "${_dst}" "${_run_mode}" "true"
            _found_any="true"
        else
            echo "欠如: ${_src}"
        fi

        _src="${_subject_src}/Diffusion"
        _dst="${_subject_dest}/Diffusion"
        if [ -d "${_src}" ]; then
            echo "同期対象: ${_src}"
            run_rsync "${_src}" "${_dst}" "${_run_mode}" "true"
            _found_any="true"
        else
            echo "欠如: ${_src}"
        fi

        _src="${_subject_src}/T1w/T1w_acpc_dc_restore_1.50.nii.gz"
        _dst="${_subject_dest}/T1w/T1w_acpc_dc_restore_1.50.nii.gz"
        if [ -f "${_src}" ]; then
            echo "同期対象: ${_src}"
            run_rsync "${_src}" "${_dst}" "${_run_mode}" "false"
            _found_any="true"
        else
            echo "欠如: ${_src}"
        fi

        if [ "${_found_any}" != "true" ]; then
            echo "警告: 同期対象が1つも見つかりませんでした。"
            echo ""
            return 1
        fi

        echo "同期完了: ${_subject_id}"
        echo ""
        return 0
    }

    function sync_lgi_mode() {
        local _subject_id=$1
        local _drv_of_subjects_on_proc=$2
        local _dest_root=$3
        local _run_mode=$4

        local _subject_src="${_drv_of_subjects_on_proc}/${_subject_id}"
        local _subject_dest="${_dest_root}/${_subject_id}"
        local _found_any="false"

        echo ""
        echo "=========================================="
        echo "被験者ID: ${_subject_id}"
        echo "モード: LGI"
        echo "同期元: ${_subject_src}"
        echo "同期先: ${_subject_dest}"
        echo "=========================================="
        echo ""

        if [ ! -d "${_subject_src}" ]; then
            echo "警告: 被験者ディレクトリが見つかりません: ${_subject_src}"
            echo "スキップします。"
            echo ""
            return 1
        fi

        local _targets=()
        local _target
        local _src
        local _dst

        _targets+=("NIDPs/${_subject_id}_LGI_MSMSulc.csv")
        _targets+=("NIDPs/${_subject_id}_LGI_MSMAll.csv")
        _targets+=("T1w/${_subject_id}/stats/lh.mean.pial_lgi.stats")
        _targets+=("T1w/${_subject_id}/stats/rh.mean.pial_lgi.stats")
        _targets+=("T1w/${_subject_id}/stats/lh.aparc.pial_lgi.stats")
        _targets+=("T1w/${_subject_id}/stats/rh.aparc.pial_lgi.stats")

        for _target in "${_targets[@]}"; do
            _src="${_subject_src}/${_target}"
            _dst="${_subject_dest}/${_target}"

            if [ -f "${_src}" ]; then
                echo "同期対象: ${_src}"
                run_rsync "${_src}" "${_dst}" "${_run_mode}" "false"
                _found_any="true"
            else
                echo "欠如: ${_src}"
            fi
        done

        if [ "${_found_any}" != "true" ]; then
            echo "警告: 同期対象が1つも見つかりませんでした。"
            echo ""
            return 1
        fi

        echo "同期完了: ${_subject_id}"
        echo ""
        return 0
    }

    function sync_single_subject() {
        local _subject_id=$1
        local _drv_of_subjects_on_proc=$2
        local _dest_root=$3
        local _run_mode=$4

        case "${mode}" in
            NIDPS)
                sync_nidps_mode "${_subject_id}" "${_drv_of_subjects_on_proc}" "${_dest_root}" "${_run_mode}"
                ;;
            DIFFUSION)
                sync_diffusion_mode "${_subject_id}" "${_drv_of_subjects_on_proc}" "${_dest_root}" "${_run_mode}"
                ;;
            LGI)
                sync_lgi_mode "${_subject_id}" "${_drv_of_subjects_on_proc}" "${_dest_root}" "${_run_mode}"
                ;;
            *)
                echo "エラー: 不正な --mode です: ${mode}"
                echo "       使用可能な値: NIDPS, DIFFUSION, LGI"
                return 1
                ;;
        esac
    }

    get_batch_options "$@"

    if [ -n "${help}" ]; then
        usage
    fi

    if [ -z "${drv_of_subjects_on_proc}" ]; then
        echo "エラー: --drv-of-subjects-on-proc が指定されていません。"
        usage
        exit 1
    fi

    if [ -z "${drv_of_subjects_on_share}" ]; then
        echo "エラー: --drv-of-subjects-on-share が指定されていません。"
        usage
        exit 1
    fi

    if [[ "${mode}" != "NIDPS" && "${mode}" != "DIFFUSION" && "${mode}" != "LGI" ]]; then
        echo "エラー: --mode には NIDPS, DIFFUSION, LGI のいずれかを指定してください。"
        usage
        exit 1
    fi

    local dest_root
    dest_root=$(build_dest_root "${drv_of_subjects_on_proc}" "${drv_of_subjects_on_share}")

    if [ "${run_mode}" == "true" ]; then
        echo ""
        echo "=== Actual-run mode ==="
        echo "実際の同期を実行します。"
    else
        echo ""
        echo "=== Dry-run mode ==="
        echo "実際の同期は行いません。--run を付けると実行します。"
    fi
    echo ""

    echo "同期設定:"
    echo "  同期元: ${drv_of_subjects_on_proc}"
    echo "  同期先: ${dest_root}"
    echo "  モード: ${mode}"
    if [[ "${keep_structure}" == "true" ]]; then
        echo "  構造保持: 有効"
    fi
    echo ""

    if [ -n "${subject_id}" ]; then
        echo "=== 単一被験者モード ==="
        echo "被験者ID: ${subject_id}"
        echo ""
        sync_single_subject "${subject_id}" "${drv_of_subjects_on_proc}" "${dest_root}" "${run_mode}"
    else
        echo "=== 全被験者モード ==="
        echo ""

        if [ ! -d "${drv_of_subjects_on_proc}" ]; then
            echo "エラー: 同期元ディレクトリが見つかりません: ${drv_of_subjects_on_proc}"
            exit 1
        fi

        local _subject_list=()
        local _dir
        for _dir in "${drv_of_subjects_on_proc}"/*/; do
            if [ -d "${_dir}" ]; then
                _subject_list+=("$(basename "${_dir}")")
            fi
        done

        local _total_subjects=${#_subject_list[@]}
        if [ ${_total_subjects} -eq 0 ]; then
            echo "警告: 処理対象の被験者が見つかりませんでした。"
            exit 0
        fi

        echo "処理対象の被験者数: ${_total_subjects}"
        echo ""

        local _processed_count=0
        local _success_count=0
        local _failed_count=0
        local _subj

        for _subj in "${_subject_list[@]}"; do
            _processed_count=$(( _processed_count + 1 ))
            echo "進捗: ${_processed_count}/${_total_subjects}"

            if sync_single_subject "${_subj}" "${drv_of_subjects_on_proc}" "${dest_root}" "${run_mode}"; then
                _success_count=$(( _success_count + 1 ))
            else
                _failed_count=$(( _failed_count + 1 ))
            fi
        done

        echo ""
        echo "=========================================="
        echo "=== 全体の処理結果サマリー ==="
        echo "総被験者数: ${_total_subjects}"
        echo "成功: ${_success_count}"
        echo "失敗/スキップ: ${_failed_count}"
        echo "=========================================="
        echo ""
    fi

    echo "${_script_name} completed"
}

sync_nidps_results "$@"
