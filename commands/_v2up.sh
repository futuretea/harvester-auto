#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _v2up namespace_id cluster_id harvester_version
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
harvester_version=$3
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh

version_file="${logs_dir}/${cluster_name}.version"
pid_file="${logs_dir}/${cluster_name}-upgrade.pid"
cleanup() {
  rm -rf "${pid_file}"
}

trap cleanup EXIT

case "${harvester_version}" in
  master)
    iso_download_url="${default_iso_download_head_url}"
    ;;
  v1.1)
    iso_download_url="${default_iso_download_head_url}"
    ;;
  v1.0)
    iso_download_url="${default_iso_download_head_url}"
    ;;
  *)
    iso_download_url="${default_iso_download_release_url}"
    ;;
esac

bash -x ./_upgrade-harvester.sh "${iso_download_url}" "${harvester_version}" "${namespace_id}" "${cluster_id}"

echo "${harvester_version}" >"${version_file}"