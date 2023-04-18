#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    snap.sh namespace_id cluster_id snapshot_name
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
snapshot_name=$3
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh

for vm_name in $(sudo virsh -q list --all | awk '{print $2}'); do
  vm="${vm_name#harvester-auto_}"
  if [[ "${vm}" != ${cluster_name}* ]]; then
    continue
  fi
  sudo virsh snapshot-create-as --domain "${vm_name}" --name "${snapshot_name}"
  echo "Created snapshot ${snapshot_name} for ${vm_name}"
done
