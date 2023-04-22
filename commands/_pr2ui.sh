#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _pr2ui namespace_id ui_prs
HELP
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

namespace_id=$1
ui_prs=$2

source _config.sh
source _util.sh

pid_file="${logs_dir}/${namespace_id}-ui.pid"
cleanup() {
  rm -rf "${pid_file}"
}
trap cleanup EXIT

bash -x ./_build-harvester-pr-ui.sh "${ui_prs}"
