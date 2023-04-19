#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    kill.sh namespace_id cluster_id job
HELP
}

kill_job() {
  local pid_file=$1
  local pid
  pid=$(awk '{print $1}' "${pid_file}")
  set +e
  pids=$(sudo pstree -p "${pid}" | awk -F '[()]' '{printf $2" "}')
  for _ in $(seq 1 10); do
    if [ -n "${pids}" ]; then
      echo "${pids}" | xargs -r kill -TERM
      sleep 1
    fi
  done
  set -e
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
job=$3

source _config.sh
source _ui_config.sh
cluster_name="harvester-${namespace_id}-${cluster_id}"

case ${job} in
"2c")
  pid_file="${logs_dir}/${cluster_name}.pid"
  ;;
"2pt")
  pid_file="${logs_dir}/${cluster_name}-patch.pid"
  ;;
"2iso")
  pid_file="${logs_dir}/${namespace_id}-iso.pid"
  ;;
"2ui")
  pid_file="${ui_logs_dir}/${namespace_id}.pid"
  ;;
"sc")
  pid_file="${logs_dir}/${cluster_name}-scale.pid"
  ;;
"up")
  pid_file="${logs_dir}/${cluster_name}-upgrade.pid"
  ;;
*)
  echo "invalid job type"
  exit 0
  ;;
esac

if [ -f "${pid_file}" ]; then
  kill_job "${pid_file}"
  echo "done"
else
  echo "job is not running"
  exit 0
fi
