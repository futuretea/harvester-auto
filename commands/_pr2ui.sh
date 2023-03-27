#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    _pr2ui user_id ui_prs
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

user_id=$1
ui_prs=$2

source _ui_config.sh
source _util.sh

fmt_ui_prs=$(sym2dash "${ui_prs}")

pid_file="${ui_logs_dir}/${user_id}.pid"
cleanup() {
  rm -rf "${pid_file}"
}
trap cleanup EXIT

bash -x ./_build-harvester-pr-ui.sh "${ui_prs}"