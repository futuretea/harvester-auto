#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    kill.sh namespace_id cluster_id job num
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
job=$3
num=${4:-20}

source _config.sh
source _ui_config.sh
cluster_name="harvester-${namespace_id}-${cluster_id}"

case ${job} in
"2c")
  log_file="${logs_dir}/${cluster_name}.log"
  ;;
"2pt")
  log_file="${logs_dir}/${cluster_name}-patch.log"
  ;;
"2ui")
  log_file="${ui_logs_dir}/${namespace_id}.log"
  ;;
"sc")
  log_file="${logs_dir}/${cluster_name}-scale.log"
  ;;
"up")
  log_file="${logs_dir}/${cluster_name}-upgrade.log"
  ;;
*)
  echo "invalid job type"
  exit 0
  ;;
esac

if [ -f "${log_file}" ]; then
  tail -n "${num}" "${log_file}"
else
  echo "N/A"
fi
