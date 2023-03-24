#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    v2c.sh harvester_version user_id cluster_id
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
log_file="${logs_dir}/${cluster_name}.log"
pid_file="${logs_dir}/${cluster_name}.pid"
version_file="${logs_dir}/${cluster_name}.version"

if [[ -f ${pid_file} ]];then
  echo "other instance running"
  exit 0
fi

mkdir -p "${logs_dir}"
nohup ./_v2c.sh "${harvester_version}" "${user_id}" "${cluster_id}" >"${log_file}" 2>&1 &
echo "$!" > "${pid_file}"
echo "${harvester_version}" > "${version_file}"

echo "got"
