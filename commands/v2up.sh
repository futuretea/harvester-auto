#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    v2up.sh namespace_id cluster_id harvester_version
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
harvester_version=$3
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
log_file="${logs_dir}/${cluster_name}-upgrade.log"
pid_file="${logs_dir}/${cluster_name}-upgrade.pid"

if [[ -f ${pid_file} ]]; then
  echo "other job running"
  exit 0
fi

mkdir -p "${logs_dir}"
nohup ./_v2up.sh "${namespace_id}" "${cluster_id}" "${harvester_version}" >"${log_file}" 2>&1 &
echo "$! v2up ${harvester_version}" >"${pid_file}"

echo "got"
