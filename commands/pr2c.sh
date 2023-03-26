#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    pr2c.sh user_id cluster_id harvester_prs installer_prs
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
log_file="${logs_dir}/${cluster_name}.log"
pid_file="${logs_dir}/${cluster_name}.pid"
version_file="${logs_dir}/${cluster_name}.version"

if [[ -f ${pid_file} ]];then
  echo "other instance running"
  exit 0
fi

mkdir -p "${logs_dir}"
nohup ./_pr2c.sh "${user_id}" "${cluster_id}" "${harvester_prs}" "${installer_prs}" "${harvester_config_url}">"${log_file}" 2>&1 &
echo "$!" > "${pid_file}"
echo "${harvester_prs}" > "${version_file}"
echo "${installer_prs}" >> "${version_file}"
echo "${harvester_config_url}" >> "${version_file}"

echo "got"
