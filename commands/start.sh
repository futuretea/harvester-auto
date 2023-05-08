#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    start.sh namespace_id cluster_id
HELP
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
cluster_name="harvester-${namespace_id}-${cluster_id}"
pxe_server_name="pxe-server-${namespace_id}-${cluster_id}"

source _config.sh

# start network
sudo virsh net-start "${cluster_name}"

# start VMs
for vm_name in $(sudo virsh -q list --all | awk '{print $2}'); do
  vm="${vm_name#harvester-auto_}"
  if [[ "${vm}" != ${cluster_name}* ]] && [[ "${vm}" != "${pxe_server_name}" ]]; then
    continue
  fi

  state=$(sudo virsh domstate "${vm_name}")
  if [ "${state}" != "running" ]; then
      sudo virsh start "${vm_name}"
  fi
done
