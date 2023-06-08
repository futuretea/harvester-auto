#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    pr2ui.sh namespace_id ui_prs is_rancher
HELP
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

namespace_id=$1
ui_prs=$2
is_rancher=$3

source _config.sh
log_file="${logs_dir}/${namespace_id}-ui.log"
pid_file="${logs_dir}/${namespace_id}-ui.pid"

if [[ -f ${pid_file} ]]; then
  echo "other job running"
  exit 0
fi

mkdir -p "${logs_dir}"
nohup ./_pr2ui.sh "${namespace_id}" "${ui_prs}" "${is_rancher}">"${log_file}" 2>&1 &
echo "$! pr2ui ${ui_prs} ${is_rancher}" >"${pid_file}"

echo "got"
