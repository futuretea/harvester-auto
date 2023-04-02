#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _pr2pt namespace_id cluster_id repo_name repo_prs
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
source _util.sh

pid_file="${logs_dir}/${cluster_name}-patch.pid"
cleanup() {
  rm -rf "${pid_file}"
}
trap cleanup EXIT

bash -x ./_build-patch-harvester-pr-image.sh "${namespace_id}" "${cluster_id}" "${repo_name}" "${repo_prs}"
