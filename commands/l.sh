#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    l.sh namespace_id
HELP
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

namespace_id=$1

source _config.sh

echo "ID NAME"
for folder in "${workspace_root}"/*; do
  if [ -d "$folder" ] && [[ "$folder" == "${workspace_root}/harvester-${namespace_id}-"* ]]; then
    awk -F "-" '{printf $3"  "}' <<<"$folder"
    if [ -f "${folder}/_name" ]; then
      cat "${folder}/_name"
    else
      echo "N/A"
    fi
  fi
done
