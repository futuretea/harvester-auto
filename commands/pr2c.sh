#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    pr2c.sh harvester_prs installer_prs user_id cluster_id
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
nohup ./_pr2c.sh "${harvester_prs}" "${installer_prs}" "${user_id}" "${cluster_id}" >"${log_file}" 2>&1 &
echo "$!" > "${pid_file}"
echo "${harvester_prs}" > "${version_file}"
echo "${installer_prs}" >> "${version_file}"

echo "got"
