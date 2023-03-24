#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    kill.sh user_id cluster_id
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
pid_file="${logs_dir}/${cluster_name}.pid"

if [[ -f ${pid_file} ]];then
  pid=$(cat "${pid_file}")
  set +e
  child_pid=$(pgrep -P "${pid}")
  kill -9 "${pid}" "${child_pid}"
  set -e
  rm -rf "${pid_file}"
fi

echo "done"
