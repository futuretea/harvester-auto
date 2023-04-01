#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    name.sh namespace_id cluster_id description
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

namespace_id=$1
cluster_id=$2
name=$3
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
workspace_cluster="${workspace_root}/${cluster_name}"

if [ -n "${name}" ]; then
  echo "${name}" > "${workspace_cluster}/_name"
  echo "done"
else
  if [ -f "${workspace_cluster}/_name" ]; then
    cat "${workspace_cluster}/_name"
  else
    echo "N/A"
  fi
fi