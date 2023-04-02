#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    scale.sh namespace_id cluster_id node_number
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
node_number=$3
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
log_file="${logs_dir}/${cluster_name}-scale.log"
pid_file="${logs_dir}/${cluster_name}-scale.pid"

if [[ -f ${pid_file} ]]; then
  echo "other job running"
  exit 0
fi

mkdir -p "${logs_dir}"
nohup ./_scale-harvester.sh "${namespace_id}" "${cluster_id}" "${node_number}" >"${log_file}" 2>&1 &
echo "$! scale ${node_number}" >"${pid_file}"

echo "got"
