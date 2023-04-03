#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    pr2up.sh namespace_id cluster_id harvester_prs installer_prs reuse_built_iso
HELP
}

if [ $# -lt 4 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
harvester_prs=$3
installer_prs=$4
reuse_built_iso=$5
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
log_file="${logs_dir}/${cluster_name}-upgrade.log"
pid_file="${logs_dir}/${cluster_name}-upgrade.pid"

if [[ -f ${pid_file} ]]; then
  echo "other job running"
  exit 0
fi

mkdir -p "${logs_dir}"
nohup ./_pr2up.sh "${namespace_id}" "${cluster_id}" "${harvester_prs}" "${installer_prs}" "${reuse_built_iso}" >"${log_file}" 2>&1 &
echo "$! pr2up ${harvester_prs} ${installer_prs} ${reuse_built_iso}" >"${pid_file}"

echo "got"
