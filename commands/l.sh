#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    cs.sh user_id
HELP
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

user_id=$1

source _config.sh

set +e
ls "${workspace_root}" | grep "harvester-${user_id}" | awk -F "-" '{print $3}'
set -e