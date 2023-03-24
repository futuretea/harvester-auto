#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -ou pipefail

usage() {
    cat <<HELP
USAGE:
    ps.sh user_id
HELP
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

user_id=$1

virsh list --all --table
