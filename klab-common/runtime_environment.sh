#!/bin/bash
#
# klab-common/runtime_environment.sh
#
# Batch Script Runner などの非対話シェルでも、手動ログイン時と同じ処理環境を
# 明示的に構築するための共通ライブラリ。このファイルは実行せず source する。
#

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "ERROR: runtime_environment.sh must be sourced." >&2
    exit 1
fi

_klabRuntimePrependPath(){
    local _directory="$1"
    [[ -d "${_directory}" ]] || return 0
    case ":${PATH}:" in
        *":${_directory}:"*) ;;
        *) PATH="${_directory}:${PATH}" ;;
    esac
    export PATH
}

# ANTs is installed outside conda on the processing machines. Do not fail here
# when a machine does not provide it: scripts that require ANTs perform their
# own dependency check.
if [[ -z "${ANTSPATH:-}" && -d /usr/local/ants-2.5.0/bin ]]; then
    export ANTSPATH=/usr/local/ants-2.5.0/bin
fi
if [[ -n "${ANTSPATH:-}" ]]; then
    _klabRuntimePrependPath "${ANTSPATH%/}"
fi

# `conda activate` is a shell function. A child `bash script.sh` does not inherit
# that function from the Runner's login shell, so initialize it again here.
if [[ "$(type -t conda 2>/dev/null)" != "function" ]]; then
    _klab_conda_executable=""
    if [[ "$(type -t conda 2>/dev/null)" == "file" ]]; then
        _klab_conda_executable="$(command -v conda)"
    else
        for _klab_conda_candidate in \
                "${HOME}/miniconda3/bin/conda" \
                "${HOME}/anaconda3/bin/conda" \
                /opt/conda/bin/conda; do
            if [[ -x "${_klab_conda_candidate}" ]]; then
                _klab_conda_executable="${_klab_conda_candidate}"
                break
            fi
        done
    fi

    if [[ -n "${_klab_conda_executable}" ]]; then
        _klab_conda_base="$("${_klab_conda_executable}" info --base 2>/dev/null)"
        if [[ -r "${_klab_conda_base}/etc/profile.d/conda.sh" ]]; then
            source "${_klab_conda_base}/etc/profile.d/conda.sh"
        fi
    fi
fi

unset _klab_conda_executable _klab_conda_candidate _klab_conda_base
unset -f _klabRuntimePrependPath

return 0
