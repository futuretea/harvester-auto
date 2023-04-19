#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    destroy.sh namespace_id cluster_id
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

log_file="${logs_dir}/${cluster_name}.log"
pid_file="${logs_dir}/${cluster_name}.pid"
version_file="${logs_dir}/${cluster_name}.version"

workspace_cluster="${workspace_root}/${cluster_name}"
workspace="${workspace_cluster}/harvester-auto"

if [[ -d "${workspace}/.vagrant" ]]; then
  cd "${workspace}"
  vagrant destroy -f
  cd "${workspace_root}"
  rm -rf "${cluster_name}"
fi

rm -f "${log_file}"
rm -f "${pid_file}"
rm -f "${version_file}"
echo "done"

if [ -n "${slack_webhook_url}" ]; then
  text="destroy cluster ${cluster_id} in namespace ${namespace_id} finished"
  curl -X POST -H 'Content-type: application/json' --data '{"text": "'"${text}"'"}' "${slack_webhook_url}"
fi
