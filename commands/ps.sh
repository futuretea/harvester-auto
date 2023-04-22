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
source _util.sh

host_ip=$(get_host_ip)
web_tail_port="8080"
web_tail_url="http://${host_ip}:${web_tail_port}"

read_pid_file() {
  local job_type=$1

  local job_file_name=
  job_file_name=$(get_job_file "${job_type}" "${namespace_id}" "${cluster_id}")

  local log_file_name="${job_file_name}.log"
  local pid_file_name="${job_file_name}.pid"

  local log_url="${web_tail_url}/#${log_file_name}"
  local pid_file="${logs_dir}/${pid_file_name}"

  if [ ! -f "${pid_file}" ]; then
    return
  fi

  local pid_file_content=
  pid_file_content=$(cat "${pid_file}")

  local pid=
  pid=$(echo "${pid_file_content}" | awk '{print $1}')

  local cmd=
  cmd=$(echo "${pid_file_content}" | awk '{$1="";print substr($0,2)}')

  echo "${job_type}        ${pid}        ${cmd}        ${log_url}"
}

echo "Type        Pid        Commands        Log"
echo "-------------------------------------------"

read_pid_file "2c"

read_pid_file "up"

read_pid_file "sc"

read_pid_file "2pt"

read_pid_file "2iso"

read_pid_file "2ui"
