#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    pods.sh namespace_id cluster_id kube_namespace
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
kube_namespace=$3
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
kubeconfig_file="${logs_dir}/${cluster_name}.kubeconfig"

if [[ -f "${kubeconfig_file}" ]]; then
  kubectl --kubeconfig="${kubeconfig_file}" -n "${kube_namespace}" get po -o wide
else
  echo "kubeconfig not found"
fi
