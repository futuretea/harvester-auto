#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    url.sh namespace_id cluster_id
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

workspace_cluster="${workspace_root}/${cluster_name}"
kubeconfig_file="${workspace_cluster}/kubeconfig"

host_ip=$(hostname -I | awk '{print $1}')
echo "Host Nginx URL: http://${host_ip}"

if [[ -f "${kubeconfig_file}" ]]; then
  echo "Socks5 Proxy URL: socks5://${host_ip}:1080"

  harvester_mgmt_url="https://10.${namespace_id}.${cluster_id}.10"
  echo "Harvester Management URL(need proxy): ${harvester_mgmt_url}"

  harvester_explorer_url=${harvester_mgmt_url}/dashboard/c/local/explorer
  echo "Harvester Embedded Rancher URL(need proxy): ${harvester_explorer_url}"

  harvester_longhorn_url=${harvester_mgmt_url}/dashboard/c/local/longhorn
  echo "Harvester Longhorn URL(need proxy): ${harvester_longhorn_url}"

  if [ -n "${nfs_root_dir}" ]; then
    nfs_cluster_dir="${nfs_root_dir}/${cluster_name}"
    if [ ! -d "${nfs_cluster_dir}" ]; then
      sudo mkdir -p "${nfs_cluster_dir}"
      sudo chown -R nobody:nogroup "${nfs_cluster_dir}"
      sudo chmod -R 777 "${nfs_cluster_dir}"
    fi
    echo "NFS Backup Target URL: nfs://${host_ip}:${nfs_cluster_dir}"
  fi
else
  echo "N/A"
fi
