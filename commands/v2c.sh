#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    v2c.sh namespace_id cluster_id harvester_version
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
harvester_version=$3
harvester_config_url=$4
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
log_file="${logs_dir}/${cluster_name}.log"
pid_file="${logs_dir}/${cluster_name}.pid"

if [[ -f ${pid_file} ]]; then
  echo "other instance running"
  exit 0
fi

mkdir -p "${logs_dir}"
nohup ./_v2c.sh "${namespace_id}" "${cluster_id}" "${harvester_version}" "${harvester_config_url}" >"${log_file}" 2>&1 &
echo "$!" >"${pid_file}"

echo "got"
