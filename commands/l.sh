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
    cluster_name=${folder#"${workspace_root}"/}
    cluster_id=$(awk -F "-" '{printf $3}' <<<"${cluster_name}")

    # cluster name
    name="N/A"
    if [ -f "${folder}/_name" ]; then
      name=$(cat "${folder}/_name")
    fi

    # cluster url
    url="N/A"
    kubeconfig_file="${logs_dir}/${cluster_name}.kubeconfig"
    if [[ -f "${kubeconfig_file}" ]]; then
      url="https://10.${namespace_id}.${cluster_id}.10"
    fi

    # cluster state
    first_node_name="harvester-auto_${cluster_name}-1"
    if grep -q "${first_node_name}" < <(sudo virsh -q list --all); then
      state=$(sudo virsh domstate "${first_node_name}")
    else
      state="N/A"
    fi
    printf "%s        %s        %s        %s        " "${cluster_id}" "${name}" "${url}" "${state}"
    if [ "${state}" == "running" ]; then
      novnc_port=$(get_vm_novnc_port "${first_node_name}")
      echo "http://${host_ip}:${novnc_port}/vnc.html"
    else
      echo "N/A"
    fi
  fi
done
