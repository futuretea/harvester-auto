#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    _pr2c user_id cluster_id harvester_prs installer_prs harvester_config_url
HELP
}

if [ $# -lt 4 ]; then
    usage
    exit 1
fi

user_id=$1
cluster_id=$2
harvester_prs=$3
installer_prs=$4
harvester_config_url=$5
cluster_name="harvester-${user_id}-${cluster_id}"

source _config.sh
source _util.sh

fmt_harvester_prs=$(sym2dash "${harvester_prs}")
fmt_installer_prs=$(sym2dash "${installer_prs}")

pid_file="${logs_dir}/${cluster_name}.pid"
cleanup() {
  rm -rf "${pid_file}"
}
trap cleanup EXIT

bash -x ./_build-harvester-pr-iso.sh "${harvester_prs}" "${installer_prs}"

host_ip=$(hostname -I | awk '{print $1}')
bash -x ./_create-harvester.sh "http://${host_ip}/harvester/${fmt_harvester_prs}-${fmt_installer_prs}" master "${default_node_number}" "${user_id}" "${cluster_id}" "${default_cpu_count}" "${default_memory_size}" "${default_disk_size}" "${harvester_config_url}"