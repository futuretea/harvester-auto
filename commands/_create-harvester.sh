#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    create-harvester.sh harvester_url harvester_version node_number user_id cluster_id cpu_count memory_size disk_size
    create-harvester.sh https://releases.rancher.com/harvester master 2 1 1 8 16384 150G
HELP
}

if [ $# -lt 8 ]; then
    usage
    exit 1
fi

harvester_url=$1
harvester_version=$2
node_number=$3
user_id=$4
cluster_id=$5
cpu_count=$6
memory_size=$7
disk_size=$8
cluster_name="harvester-${user_id}-${cluster_id}"

source _config.sh
workspace_cluster="${workspace_root}/${cluster_name}"
workspace="${workspace_cluster}/harvester-auto"

# check exist
if [[ -d "${workspace}/.vagrant" ]];then
   printf "destroy existing cluster %d\n" "${cluster_id}"
  if [[ -d "${workspace}/.vagrant" ]]; then
    cd "${workspace}"
    vagrant destroy -f
    cd -
    rm -rf "${workspace_cluster}"
  fi
fi

# create
mkdir -p "${workspace_cluster}"
cd "${workspace_cluster}"
git clone -b "${git_repo_branch}" "${git_repo_url}"
cd "${git_repo_name}"
jinja2 settings.yml.j2 \
    -D harvester_url=${harvester_url} \
    -D harvester_version=${harvester_version} \
    -D node_number=${node_number} \
    -D user_id=${user_id} \
    -D cluster_id=${cluster_id} \
    -D cpu_count=${cpu_count} \
    -D memory_size=${memory_size} \
    -D disk_size=${disk_size} >settings.yml
bash -x ./setup_harvester.sh
vagrant status

mgmt_ip="10.${user_id}.${cluster_id}.10"

harvester_mgmt_url="https://${mgmt_ip}"
echo "${harvester_mgmt_url}" > harvester_mgmt_url.txt
printf "harvester mgmt url: %s\n" "${harvester_mgmt_url}"
