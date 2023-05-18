#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _pr2up namespace_id cluster_id harvester_prs installer_prs reuse_built_iso
HELP
}

if [ $# -lt 4 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
harvester_prs=$3
installer_prs=$4
reuse_built_iso=$5
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
source _util.sh

fmt_harvester_prs=$(sym2dash "${harvester_prs}")
fmt_installer_prs=$(sym2dash "${installer_prs}")

workspace_cluster="${workspace_root}/${cluster_name}"
version_file="${workspace_cluster}/version"

pid_file="${logs_dir}/${cluster_name}-upgrade.pid"
cleanup() {
  rm -rf "${pid_file}"
}
trap cleanup EXIT

if [ "${reuse_built_iso}" != "true" ]; then
  bash -x ./_build-harvester-pr-iso.sh "${harvester_prs}" "${installer_prs}"
fi

harvester_iso_download_oss_url=$(mc alias ls "${harvester_iso_upload_oss_alias}" --json | jq -r '.URL')
bash -x ./_upgrade-harvester.sh "${harvester_iso_download_oss_url}/${harvester_iso_upload_bucket_name}/${fmt_harvester_prs}-${fmt_installer_prs}" master "${namespace_id}" "${cluster_id}"

echo "harvester/harvester PRs: ${harvester_prs}" >"${version_file}"
echo "harvester/harvester-installer PRs: ${installer_prs}" >>"${version_file}"
