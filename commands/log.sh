#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    log.sh namespace_id cluster_id job_type num
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
job_type=$3
num=${4:-20}

source _config.sh
source _util.sh

job_file_name=$(get_job_file "${job_type}" "${namespace_id}" "${cluster_id}")

log_file="${logs_dir}/${job_file_name}.log"

if [ -f "${log_file}" ]; then
  tail -n "${num}" "${log_file}"
else
  echo "N/A"
fi
