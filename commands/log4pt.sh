#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    log4pt.sh user_id cluster_id num
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

user_id=$1
cluster_id=$2
num=${3:-20}
cluster_name="harvester-${user_id}-${cluster_id}"

source _config.sh
log_file="${logs_dir}/${cluster_name}-patch.log"

if [[ -f ${log_file} ]];then
	tail -n "${num}" "${log_file}"
else
	echo "N/A"
fi
