#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    l.sh namespace_id
HELP
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

namespace_id=$1

source _config.sh
source _util.sh
host_ip=$(get_host_ip)

echo "Id        Name        URL        State        Console"
echo "--------------------------------------------------"
for folder in "${workspace_root}"/*; do
  if [ -d "${folder}" ] && [[ "${folder}" == "${workspace_root}/harvester-${namespace_id}-"* ]]; then
    cluster_name=${folder#${workspace_root}/}
    cluster_id=$(awk -F "-" '{printf $3}' <<<"${cluster_name}")

    # cluster name
    name="N/A"
    if [ -f "${folder}/_name" ]; then
      name=$(cat "${folder}/_name")
    fi

    # cluster url
    workspace_cluster="${workspace_root}/${cluster_name}"
    workspace="${workspace_cluster}/harvester-auto"
    url="N/A"
    harvester_mgmt_url_file="${workspace}/harvester_mgmt_url.txt"
    if [[ -f "${harvester_mgmt_url_file}" ]]; then
      url=$(cat "${harvester_mgmt_url_file}")
    fi

    # cluster state
    first_node_name="harvester-auto_${cluster_name}-1"
    state=$(sudo virsh domstate "${first_node_name}")
    printf "%s        %s        %s        %s        " "${cluster_id}" "${name}" "${url}" "${state}"
    if [ "${state}" == "running" ]; then
      novnc_port=$(get_vm_novnc_port "${first_node_name}")
      echo "http://${host_ip}:${novnc_port}/vnc.html"
    else
      echo "N/A"
    fi
  fi
done
