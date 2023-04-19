#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -ou pipefail

usage() {
  cat <<HELP
USAGE:
    ps.sh namespace_id cluster_id
HELP
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2

source _config.sh
source _ui_config.sh
cluster_name="harvester-${namespace_id}-${cluster_id}"
pid_file="${logs_dir}/${cluster_name}.pid"
patch_pid_file="${logs_dir}/${cluster_name}-patch.pid"
iso_pid_file="${logs_dir}/${namespace_id}-iso.pid"
upgrade_pid_file="${logs_dir}/${cluster_name}-upgrade.pid"
scale_pid_file="${logs_dir}/${cluster_name}-scale.pid"
ui_pid_file="${ui_logs_dir}/${namespace_id}.pid"

if [[ -f ${pid_file} ]]; then
  echo "2c: $(cat "${pid_file}")"
else
  echo "2c: N/A"
fi

if [[ -f ${patch_pid_file} ]]; then
  echo "2pt: $(cat "${patch_pid_file}")"
else
  echo "2pt: N/A"
fi

if [[ -f ${iso_pid_file} ]]; then
  echo "2iso: $(cat "${iso_pid_file}")"
else
  echo "2iso: N/A"
fi

if [[ -f ${ui_pid_file} ]]; then
  echo "2ui: $(cat "${ui_pid_file}")"
else
  echo "2ui: N/A"
fi

if [[ -f ${scale_pid_file} ]]; then
  echo "sc: $(cat "${scale_pid_file}")"
else
  echo "sc: N/A"
fi

if [[ -f ${upgrade_pid_file} ]]; then
  echo "up: $(cat "${upgrade_pid_file}")"
else
  echo "up: N/A"
fi
