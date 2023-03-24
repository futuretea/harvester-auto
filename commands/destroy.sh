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

log_file="${logs_dir}/${cluster_name}.log"
pid_file="${logs_dir}/${cluster_name}.pid"
version_file="${logs_dir}/${cluster_name}.version"

workspace_cluster="${workspace_root}/${cluster_name}"
workspace="${workspace_cluster}/harvester-auto"

if [[ -d "${workspace}/.vagrant" ]]; then
  cd "${workspace}"
  vagrant destroy -f
#  rm -rf .vagrant
#  set +e
#  virsh net-destroy "${cluster_name}"
#  set -e
  cd "${workspace_root}"
  rm -rf "${cluster_name}"
fi
docker rm -f "${cluster_name}-proxy"
rm -f "${log_file}"
rm -f "${pid_file}"
rm -f "${version_file}"
echo "done"
