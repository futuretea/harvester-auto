#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    build-push-harvester-pr-image user_id cluster_id repo_name repo_prs
HELP
}

if [ $# -lt 4 ]; then
    usage
    exit 1
fi

user_id=$1
cluster_id=$2
repo_name=$3
repo_prs=$4
cluster_name="harvester-${user_id}-${cluster_id}"

# pwd: commands
source _config.sh
source _util.sh

fmt_repo_prs=$(sym2dash "${repo_prs}")

TIMESTAMP=$(date +%Y%m%d%H%M%S)
TEMPDIR=$(mktemp -d -t "harvester-auto-s2i-${TIMESTAMP}-XXXXX")
printf "TEMP_DIR=%s\n" "${TEMPDIR}"

cd "${TEMPDIR}"
# pwd: TEMPDIR

git clone "https://github.com/harvester/${repo_name}.git"
cd "${repo_name}"
# pwd: TEMPDIR/${repo_name}

prs="${repo_prs}"
if [[ ${prs} != "0" ]];then
  # prepare code
  IFS=',' read -ra prs_arr <<< "${prs}"
  if [[ ${#prs_arr[@]} -eq 1 ]]; then
    if [[ "${prs}" =~ ^[0-9]+$ ]];then
      fetch_checkout_pr "${prs}"
    else
      fetch_checkout_fork "${repo_name}" "${prs}"
    fi
  else
    git checkout -b "pr-${fmt_repo_prs}"
    for i in "${prs_arr[@]}"; do
      if [[ "${i}" =~ ^[0-9]+$ ]];then
        fetch_merge_pr "${i}"
      else
        fetch_merge_fork "${repo_name}" "${i}"
      fi
    done
  fi
fi

# build
make

harvester-push-images "${push_image_repo}"

kubeconfig_file="${logs_dir}/${cluster_name}.kubeconfig"
export KUBECONFIG="${kubeconfig_file}"
harvester-patch-images "${push_image_repo}"

# clean
rm -rf "${TEMPDIR}"
