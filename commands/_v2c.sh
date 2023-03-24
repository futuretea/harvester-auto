#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    _v2c harvester_version user_id cluster_id
HELP
}

if [ $# -lt 3 ]; then
    usage
    exit 1
fi

harvester_version=$1
user_id=$2
cluster_id=$3
cluster_name="harvester-${user_id}-${cluster_id}"

source _config.sh

pid_file="${logs_dir}/${cluster_name}.pid"
cleanup() {
  rm -rf "${pid_file}"
}

trap cleanup EXIT

bash -x ./_create-harvester.sh "${default_iso_download_url}" "${harvester_version}" "${default_node_number}" "${user_id}" "${cluster_id}" "${default_cpu_count}" "${default_memory_size}" "${default_disk_size}"