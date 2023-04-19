#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    settings.sh namespace_id cluster_id
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
kubeconfig_file="${logs_dir}/${cluster_name}.kubeconfig"

if [[ -f "${kubeconfig_file}" ]]; then
  kubectl --kubeconfig="${kubeconfig_file}" get settings -ojson | jq -r '.items[] | .metadata.name+":"+(if .value then .value else .default end)'
else
  echo "kubeconfig not found"
fi
