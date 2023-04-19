#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _pr2iso namespace_id harvester_prs installer_prs
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
source _util.sh

pid_file="${logs_dir}/${namespace_id}-iso.pid"
cleanup() {
  rm -rf "${pid_file}"
}
trap cleanup EXIT

bash -x ./_build-harvester-pr-iso.sh "${harvester_prs}" "${installer_prs}"
