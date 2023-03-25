#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    _pr2c harvester_prs installer_prs user_id cluster_id harvester_config_url
HELP
}

if [ $# -lt 4 ]; then
    usage
    exit 1
fi

harvester_prs=$1
installer_prs=$2
user_id=$3
cluster_id=$4
harvester_config_url=$5
cluster_name="harvester-${user_id}-${cluster_id}"

source _config.sh

pid_file="${logs_dir}/${cluster_name}.pid"
cleanup() {
  rm -rf "${pid_file}"
}

trap cleanup EXIT

export REPO=${REPO:-"${default_image_repo}"}

bash -x ./_build-harvester-pr-iso.sh "${harvester_prs}" "${installer_prs}"

host_ip=$(hostname -I | awk '{print $1}')
bash -x ./_create-harvester.sh "http://${host_ip}/harvester/${harvester_prs//,/-}-${installer_prs//,/-}" master "${default_node_number}" "${user_id}" "${cluster_id}" "${default_cpu_count}" "${default_memory_size}" "${default_disk_size}" "${harvester_config_url}"