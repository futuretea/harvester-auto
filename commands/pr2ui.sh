#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    pr2ui.sh user_id ui_prs
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

user_id=$1
ui_prs=$2

source _ui_config.sh
ui_log_file="${ui_logs_dir}/${user_id}.log"
ui_pid_file="${ui_logs_dir}/${user_id}.pid"
ui_version_file="${ui_logs_dir}/${user_id}.version"

if [[ -f ${ui_pid_file} ]];then
  echo "other job running"
  exit 0
fi

mkdir -p "${ui_logs_dir}"
nohup ./_pr2ui.sh "${user_id}" "${ui_prs}">"${ui_log_file}" 2>&1 &
echo "$!" > "${ui_pid_file}"
echo "harvester/dashboard PRs: ${ui_prs}" > "${ui_version_file}"

echo "got"
