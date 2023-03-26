#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    _v2c user_id cluster_id harvester_version harvester_config_url
HELP
}

if [ $# -lt 3 ]; then
    usage
    exit 1
fi

user_id=$1
cluster_id=$2
harvester_version=$3
harvester_config_url=$4
cluster_name="harvester-${user_id}-${cluster_id}"

source _config.sh

pid_file="${logs_dir}/${cluster_name}.pid"
cleanup() {
  rm -rf "${pid_file}"
}

trap cleanup EXIT

bash -x ./_create-harvester.sh "${default_iso_download_url}" "${harvester_version}" "${default_node_number}" "${user_id}" "${cluster_id}" "${default_cpu_count}" "${default_memory_size}" "${default_disk_size}" "${harvester_config_url}"