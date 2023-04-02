#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _scale-harvester.sh namespace_id cluster_id node_number
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
node_number=$3
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh

workspace_cluster="${workspace_root}/${cluster_name}"
workspace="${workspace_cluster}/harvester-auto"

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

# create
cd "${workspace}"

cat settings.yml | yq e '.harvester_cluster_create_nodes = '"${node_number}"'' >settings.yml.tmp
mv settings.yml.tmp settings.yml

ansible-playbook ansible/scale_harvester.yml --extra-vars "@settings.yml" --extra-vars "node_number=${node_number}"
