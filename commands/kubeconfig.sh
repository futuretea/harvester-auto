#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    kubeconfig.sh namespace_id cluster_id
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
kubeconfig_file="${logs_dir}/${cluster_name}.kubeconfig"

if [ ! -f "${kubeconfig_file}" ];then
  echo "N/A"
  exit 0
fi

# update kubeconfig  proxy-url
host_ip=$(hostname -I | awk '{print $1}')
socks5_ip=${host_ip}
socks5_port=1080
cat "${kubeconfig_file}" | yq e '.clusters[0].cluster.proxy-url = "socks5://'"${socks5_ip}:${socks5_port}"'"' -