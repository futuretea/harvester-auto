#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    version.sh namespace_id cluster_id num
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

namespace_id=$1
cluster_id=$2
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
version_file="${logs_dir}/${cluster_name}.version"

if [[ -f ${version_file} ]];then
	cat "${version_file}"
else
	echo "N/A"
fi

