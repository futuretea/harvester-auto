#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    ui_tail.sh user_id num
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

user_id=$1
num=${3:-20}

source _ui_config.sh
ui_log_file="${ui_logs_dir}/${user_id}.log"

if [[ -f ${ui_log_file} ]];then
	tail -n "${num}" "${ui_log_file}"
else
	echo "N/A"
fi

