#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    up.sh namespace_id cluster_id
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

namespace_id=$1
cluster_id=$2
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
workspace_cluster="${workspace_root}/${cluster_name}"
workspace="${workspace_cluster}/harvester-auto"

if [[ -d "${workspace}/.vagrant" ]]; then
  cd "${workspace}"
  vagrant up
  echo "done"
else
  echo "cluster not created"
fi
