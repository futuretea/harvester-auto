#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _create-harvester.sh harvester_url harvester_version namespace_id cluster_id harvester_config_url
    _create-harvester.sh https://releases.rancher.com/harvester master 1 1
HELP
}

if [ $# -lt 4 ]; then
  usage
  exit 1
fi

harvester_url=$1
harvester_version=$2
namespace_id=$3
cluster_id=$4
harvester_config_url=${5:-""}
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh
source _util.sh

workspace_cluster="${workspace_root}/${cluster_name}"
workspace="${workspace_cluster}/harvester-auto"

TOP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
terraform_vars_file="${TOP_DIR}/terraform/terraform.tfvars"

kubeconfig_file="${workspace_cluster}/kubeconfig"
version_file="${workspace_cluster}/version"

# destroy exist
if [[ -d "${workspace}/.vagrant" ]]; then
  printf "destroy existing cluster %d\n" "${cluster_id}"
  if [[ -d "${workspace}/.vagrant" ]]; then
    cd "${workspace}"
    vagrant destroy -f
    cd -
    rm -rf "${workspace}"
  fi
fi

rm -f "${version_file}"

# create
mkdir -p "${workspace_cluster}"
cd "${workspace_cluster}"
git clone -b "${git_repo_branch}" "${git_repo_url}"
cd "${git_repo_name}"
jinja2 settings.yml.j2 \
  -D harvester_url="${harvester_url}" \
  -D harvester_version="${harvester_version}" \
  -D namespace_id="${namespace_id}" \
  -D cluster_id="${cluster_id}" \
  -D harvester_config_url="${harvester_config_url}" \
  -D dns_nameserver="${default_dns_nameserver}" \
  -D create_node_number="${default_create_node_number}" \
  -D node_number="${default_node_number}" \
  -D cpu_count="${default_cpu_count}" \
  -D memory_size="${default_memory_size}" \
  -D disk_size="${default_disk_size}" >settings.yml

ansible-playbook ansible/setup_harvester.yml --extra-vars "@settings.yml"

# set network autostart
sudo virsh net-autostart "${cluster_name}"
sudo virsh net-autostart vagrant-libvirt

# fetch kubeconfig
first_node_ip="10.${namespace_id}.${cluster_id}.11"
sshpass -p "${default_node_password}" ssh -tt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no rancher@"${first_node_ip}" sudo cat "/etc/rancher/rke2/rke2.yaml" >"${kubeconfig_file}.src" 2>/dev/null
cat "${kubeconfig_file}.src" | yq e '.clusters[0].cluster.server = "https://'"${first_node_ip}"':6443"' - >"${kubeconfig_file}"

# wait harvester ready
wait_harvester_ready "${kubeconfig_file}"

# init cluster by ${workspace}/terraform
if [[ -d "terraform" ]]; then
  cd "terraform"

  ln -s "${kubeconfig_file}" local.yaml

  terraform init

  if [[ -f "${terraform_vars_file}" ]]; then
    cp "${terraform_vars_file}" terraform.tfvars
  else
    cp "${terraform_vars_file}.example" terraform.tfvars
  fi

  terraform apply -auto-approve -var-file="terraform.tfvars"
fi

if [ -n "${slack_webhook_url}" ]; then
  text="create cluster ${cluster_id} in namespace ${namespace_id} finished"
  curl -X POST -H 'Content-type: application/json' --data '{"text": "'"${text}"'"}' "${slack_webhook_url}"
fi
