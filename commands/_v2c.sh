#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _v2c namespace_id cluster_id harvester_version harvester_config_url
HELP
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
harvester_version=$3
harvester_config_url=$4
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh

workspace_cluster="${workspace_root}/${cluster_name}"
version_file="${workspace_cluster}/version"

pid_file="${logs_dir}/${cluster_name}.pid"
cleanup() {
  rm -rf "${pid_file}"
}

trap cleanup EXIT

case "${harvester_version}" in
  master)
    iso_download_url="${default_iso_download_head_url}"
    ;;
  v1.2)
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

bash -x ./_create-harvester.sh "${iso_download_url}" "${harvester_version}" "${namespace_id}" "${cluster_id}" "${harvester_config_url}"

echo "${harvester_version}" >"${version_file}"
echo "${harvester_config_url}" >>"${version_file}"
