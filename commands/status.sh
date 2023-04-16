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
base64_node_password=$(echo "${default_node_password}" | base64)
echo "Cluster        Node        State        Console        SSH"
echo "-------------------------------------------------------------"

for vm_name in $(sudo virsh -q list --all | awk '{print $2}'); do
  vm="${vm_name#harvester-auto_}"
  if [[ ! "${vm}" == ${cluster_name}* ]]; then
    continue
  fi

  node_index="${vm#${cluster_name}-}"
  node_ip="10.${namespace_id}.${cluster_id}.1${node_index}"
  state=$(sudo virsh domstate "${vm_name}")
  printf "%s        %s        %s        " "${cluster_id}" "${node_ip}" "${state}"

  if [ "${state}" == "running" ]; then
    novnc_port=$(get_vm_novnc_port "${vm_name}")
    web_ssh_url="http://${host_ip}:8888/?hostname=${node_ip}&username=rancher&password=${base64_node_password}"
    echo "http://${host_ip}:${novnc_port}/vnc.html        ${web_ssh_url}"
  else
    echo "N/A        N/A"
  fi

done
