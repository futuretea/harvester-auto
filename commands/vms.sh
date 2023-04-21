#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    get.sh namespace_id cluster_id kube_namespace
HELP
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
kube_namespace=$3
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh

workspace_cluster="${workspace_root}/${cluster_name}"
kubeconfig_file="${workspace_cluster}/kubeconfig"

if [[ -f "${kubeconfig_file}" ]]; then
  kubectl --kubeconfig="${kubeconfig_file}" -n "${kube_namespace}" get vm
else
  echo "kubeconfig not found"
fi
