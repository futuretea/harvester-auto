#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    status.sh namespace_id cluster_id
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
source _util.sh
host_ip=$(get_host_ip)

echo "Cluster        Node        State        Console"
echo "-------------------------------------------------"

for vm_name in $(sudo virsh -q list --all | awk '{print $2}'); do
  vm="${vm_name#harvester-auto_}"
  if [[ ! "${vm}" == ${cluster_name}* ]]; then
    continue
  fi

  node_index="${vm#${cluster_name}-}"
  state=$(sudo virsh domstate "${vm_name}")
  printf "%s   %s   %s   " "${cluster_id}" "${node_index}" "${state}"

  if [ "${state}" == "running" ]; then
    novnc_port=$(get_vm_novnc_port "${vm_name}")
    echo "http://${host_ip}:${novnc_port}/vnc.html"
  else
    echo "N/A"
  fi

done
