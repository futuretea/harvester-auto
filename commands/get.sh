#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    get.sh namespace_id cluster_id args
HELP
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
cluster_name="harvester-${namespace_id}-${cluster_id}"
shift 2

source _config.sh
kubeconfig_file="${logs_dir}/${cluster_name}.kubeconfig"

if [[ -f "${kubeconfig_file}" ]]; then
  kubectl --kubeconfig=${kubeconfig_file} get $@
else
  echo "kubeconfig not found"
fi
