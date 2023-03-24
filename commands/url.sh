#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    url.sh user_id cluster_id
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

user_id=$1
cluster_id=$2
cluster_name="harvester-${user_id}-${cluster_id}"

source _config.sh
workspace_cluster="${workspace_root}/${cluster_name}"
workspace="${workspace_cluster}/harvester-auto"

harvester_mgmt_url_file="${workspace}/harvester_mgmt_url.txt"
if [[ -f "${harvester_mgmt_url_file}" ]]; then

  harvester_mgmt_url=$(cat "${harvester_mgmt_url_file}")
  echo "harvester mgmt url: ${harvester_mgmt_url}"

  harvester_explorer_url=${harvester_mgmt_url}/dashboard/c/local/explorer
  echo "harvester explorer url: ${harvester_explorer_url}"

  harvester_longhorn_url=${harvester_mgmt_url}/dashboard/c/local/longhorn
  echo "harvester longhorn url: ${harvester_longhorn_url}"

  local_ip=$(hostname -I | awk '{print $1}')
  harvester_image_url=${local_ip}/images
  echo "harvester image url: ${harvester_image_url}"
else
  echo "N/A"
fi
