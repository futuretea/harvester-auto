#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _build-patch-harvester-pr-image namespace_id cluster_id repo_name repo_prs
HELP
}

if [ $# -lt 4 ]; then
  usage
  exit 1
fi

namespace_id=$1
cluster_id=$2
repo_name=$3
repo_prs=$4
cluster_name="harvester-${namespace_id}-${cluster_id}"

# pwd: commands
source _config.sh
source _util.sh

fmt_repo_prs=$(sym2dash "${repo_prs}")

IFS="@" read -r repo_prs repo_target_branch <<<"${repo_prs}"

if [ -z "${repo_target_branch}" ]; then
  repo_target_branch="${backend_base_branch}"
fi

echo "repo_prs: ${repo_prs}"
echo "repo_target_branch: ${repo_target_branch}"
echo "repo_base_branch: ${backend_base_branch}"

workspace_cluster="${workspace_root}/${cluster_name}"
kubeconfig_file="${workspace_cluster}/kubeconfig"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
TEMPDIR=$(mktemp -d -t "harvester-auto-patch-${TIMESTAMP}-XXXXX")
printf "TEMP_DIR=%s\n" "${TEMPDIR}"

cd "${TEMPDIR}"
# pwd: TEMPDIR

git clone "https://github.com/harvester/${repo_name}.git"
cd "${repo_name}"
# pwd: TEMPDIR/${repo_name}

prepare_code "harvester" "${repo_name}" "${repo_prs}" "${fmt_repo_prs}" "${repo_target_branch}" "${backend_base_branch}"

# build
make

harvester-push-images "${default_image_repo}"
export KUBECONFIG="${kubeconfig_file}"
harvester-patch-images "${default_image_repo}"

# clean
rm -rf "${TEMPDIR}"

if [ -n "${slack_webhook_url}" ]; then
  text="patch cluster ${cluster_id} in namespace ${namespace_id} finished"
  curl -X POST -H 'Content-type: application/json' --data '{"text": "'"${text}"'"}' "${slack_webhook_url}"
fi
