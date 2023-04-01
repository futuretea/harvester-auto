#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    images.sh user_id cluster_id namespace
HELP
}

if [ $# -lt 3 ]; then
    usage
    exit 1
fi

user_id=$1
cluster_id=$2
namespace=$3
cluster_name="harvester-${user_id}-${cluster_id}"

source _config.sh
kubeconfig_file="${logs_dir}/${cluster_name}.kubeconfig"

if [[ -f "${kubeconfig_file}" ]];then
    kubectl --kubeconfig=${kubeconfig_file} -n ${namespace} get po -o custom-columns='NAME:metadata.name,IMAGES:spec.containers[*].image'
else
  echo "kubeconfig not found"
fi