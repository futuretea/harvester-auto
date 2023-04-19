#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    snaps.sh namespace_id cluster_id
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

for vm_name in $(sudo virsh -q list --all | awk '{print $2}'); do
  vm="${vm_name#harvester-auto_}"
  if [[ "${vm}" != ${cluster_name}* ]]; then
    continue
  fi
  node_index="${vm#"${cluster_name}-"}"
  echo "node-${node_index}:"
  sudo virsh snapshot-list --domain "${vm_name}"
done
