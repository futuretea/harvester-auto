#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    kill.sh namespace_id cluster_id job_type
HELP
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
