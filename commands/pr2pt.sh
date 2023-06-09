#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    pr2pt.sh namespace_id cluster_id repo_name repo_prs
HELP
}

if [ $# -lt 4 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
repo_name=$3
repo_prs=$4
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
log_file="${logs_dir}/${cluster_name}-patch.log"
pid_file="${logs_dir}/${cluster_name}-patch.pid"

if [[ -f ${pid_file} ]]; then
  echo "other job running"
  exit 0
fi

mkdir -p "${logs_dir}"
nohup ./_pr2pt.sh "${namespace_id}" "${cluster_id}" "${repo_name}" "${repo_prs}" >"${log_file}" 2>&1 &
echo "$! pr2pt ${repo_name} ${repo_prs}" >"${pid_file}"

echo "got"
