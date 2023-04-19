#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    pr2iso.sh namespace_id harvester_prs installer_prs
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
harvester_prs=$2
installer_prs=$3

source _config.sh
log_file="${logs_dir}/${namespace_id}-iso.log"
pid_file="${logs_dir}/${namespace_id}-iso.pid"

if [[ -f ${pid_file} ]]; then
  echo "other instance running"
  exit 0
fi

mkdir -p "${logs_dir}"
nohup ./_pr2iso.sh "${namespace_id}" "${harvester_prs}" "${installer_prs}" >"${log_file}" 2>&1 &
echo "$! pr2iso ${harvester_prs} ${installer_prs}" >"${pid_file}"

echo "got"
