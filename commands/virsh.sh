#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    virsh.sh command args
HELP
}

function string_in_list() {
  local string="$1"
  shift
  local list=("$@")
  for item in "${list[@]}"; do
    if [[ "$item" == "$string" ]]; then
      return 0
    fi
  done
  return 1
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

command=$1
shift 1

allowed_commands=("-h" "list" "start" "shutdown" "reboot" "destroy" "dumpxml" "net-list" "net-destroy" "net-dumpxml" "net-info" "net-dhcp-leases" "snapshot-create" "snapshot-list" "snapshot-revert" "snapshot-delete")
if [[ -z ${command} ]]; then
  echo "allowed commands: ${allowed_commands[*]}"
  exit 0
fi

if string_in_list "${command}" "${allowed_commands[@]}"; then
  sudo virsh "${command}" "$@"
else
  echo "${command} is not allowed"
fi
