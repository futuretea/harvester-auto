#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    kill.sh namespace_id cluster_id job_type
HELP
}

kill_job() {
  local pid_file=$1
  local pid
  pid=$(awk '{print $1}' "${pid_file}")
  set +e
  pids=$(sudo pstree -p "${pid}" | awk -F '[()]' '{printf $2" "}')
  for _ in $(seq 1 10); do
    if [ -n "${pids}" ]; then
      echo "${pids}" | xargs -r kill -TERM
      sleep 1
    fi
  done
  set -e
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
job_type=$3

source _config.sh
source _util.sh

job_file_name=$(get_job_file "${job_type}" "${namespace_id}" "${cluster_id}")

pid_file="${logs_dir}/${job_file_name}.pid"
if [ -f "${pid_file}" ]; then
  kill_job "${pid_file}"
  echo "done"
else
  echo "job is not running"
  exit 0
fi
