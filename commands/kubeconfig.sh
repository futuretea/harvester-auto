#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    url.sh user_id cluster_id
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

user_id=$1
cluster_id=$2
cluster_name="harvester-${user_id}-${cluster_id}"

source _config.sh
kubeconfig_file="${logs_dir}/${cluster_name}.kubeconfig"

# get kubeconfig from the first node
first_node_ip="10.${user_id}.${cluster_id}.11"
sshpass -p "${default_node_password}" ssh -tt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no rancher@"${first_node_ip}" sudo cat "/etc/rancher/rke2/rke2.yaml" > ${kubeconfig_file} 2>/dev/null

# update kubeconfig server and proxy-url
host_ip=$(hostname -I | awk '{print $1}')
socks5_ip=${host_ip}
socks5_port=1080
cat "${kubeconfig_file}" | yq e '.clusters[0].cluster.server = "https://'"${first_node_ip}"':6443"' - | yq e '.clusters[0].cluster.proxy-url = "socks5://'"${socks5_ip}:${socks5_port}"'"' -