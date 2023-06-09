#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _scale-harvester.sh namespace_id cluster_id spec_node_number
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
spec_node_number=$3
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
source _util.sh

workspace_cluster="${workspace_root}/${cluster_name}"
workspace="${workspace_cluster}/harvester-auto"

kubeconfig_file="${workspace_cluster}/kubeconfig"

pid_file="${logs_dir}/${cluster_name}-scale.pid"
cleanup() {
  rm -rf "${pid_file}"
}
trap cleanup EXIT

# check exist
if [[ ! -d "${workspace}/.vagrant" ]]; then
  echo "cluster not exist"
  exit 1
fi

# scale cluster
cd "${workspace}"

cat settings.yml | yq e '.harvester_cluster_create_nodes = '"${spec_node_number}"'' >settings.yml.tmp
mv settings.yml.tmp settings.yml

ansible-playbook ansible/scale_harvester.yml --extra-vars "@settings.yml" --extra-vars "spec_node_number=${spec_node_number}"

# wait harvester ready
wait_harvester_ready "${kubeconfig_file}"

if [ -n "${slack_webhook_url}" ]; then
  text="scale cluster ${cluster_id} in namespace ${namespace_id} finished"
  curl -X POST -H 'Content-type: application/json' --data '{"text": "'"${text}"'"}' "${slack_webhook_url}"
fi
