#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -ou pipefail

usage() {
  cat <<HELP
USAGE:
    ps.sh namespace_id cluster_id
HELP
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2

source _config.sh
source _ui_config.sh
source _util.sh

cluster_name="harvester-${namespace_id}-${cluster_id}"

pid_file="${logs_dir}/${cluster_name}.pid"
patch_pid_file="${logs_dir}/${cluster_name}-patch.pid"
iso_pid_file="${logs_dir}/${namespace_id}-iso.pid"
upgrade_pid_file="${logs_dir}/${cluster_name}-upgrade.pid"
scale_pid_file="${logs_dir}/${cluster_name}-scale.pid"
ui_pid_file="${ui_logs_dir}/${namespace_id}.pid"

log_file_name="${cluster_name}.log"
patch_log_file_name="${cluster_name}-patch.log"
iso_log_file_name="${namespace_id}-iso.log"
upgrade_log_file_name="${cluster_name}-upgrade.log"
scale_log_file_name="${cluster_name}-scale.log"
ui_log_file_name="${namespace_id}.log"

host_ip=$(get_host_ip)
web_tail_port="8080"
web_tail_url="http://${host_ip}:${web_tail_port}"

read_pid_file(){
    local pid_file=$1
    local pid_type=$2
    local log_file_name=$3
    local pid_file_content=
    local pid=
    local cmd=
    local log_url="${web_tail_url}/#${log_file_name}"
    pid_file_content=$(cat "${pid_file}")
    pid=$(echo "${pid_file_content}" | awk '{print $1}')
    cmd=$(echo "${pid_file_content}" | awk '{$1="";print substr($0,2)}')
    echo "${pid_type}        ${pid}        ${cmd}        ${log_url}"
}

echo "Type        Pid        Commands        Log"
echo "-------------------------------------------"
if [[ -f ${pid_file} ]]; then
  read_pid_file "${pid_file}" "2c" "${log_file_name}"
fi

if [[ -f ${patch_pid_file} ]]; then
  read_pid_file "${patch_pid_file}" "2pt" "${patch_log_file_name}"

fi

if [[ -f ${iso_pid_file} ]]; then
  read_pid_file "${iso_pid_file}" "2iso" "${iso_log_file_name}"
fi

if [[ -f ${ui_pid_file} ]]; then
  read_pid_file "${ui_pid_file}" "2ui" "${ui_log_file_name}"
fi

if [[ -f ${scale_pid_file} ]]; then
  read_pid_file "${scale_pid_file}" "sc" "${scale_log_file_name}"
fi

if [[ -f ${upgrade_pid_file} ]]; then
  read_pid_file "${upgrade_pid_file}" "up" "${upgrade_log_file_name}"
fi


