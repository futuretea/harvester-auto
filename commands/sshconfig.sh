#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    sshconfig.sh user_id cluster_id
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
version_file="${logs_dir}/${cluster_name}.version"

if [ ! -f "${version_file}" ];then
  echo "N/A"
  exit 0
fi

host_ip=$(hostname -I | awk '{print $1}')

cat <<EOF
Host harvester-auto-host
    hostname ${host_ip}
    user rancher
EOF

cat <<EOF
# password defaults to vagrant
Host ${cluster_name}-pxe-server
    hostname 10.${user_id}.${cluster_id}.254
    user vagrant
    proxyJump harvester-auto-host
EOF

for i in $(seq 1 "${default_node_number}");do
cat <<EOF
# password defaults to ${default_node_password}
Host ${cluster_name}-node-${i}
    hostname 10.${user_id}.${cluster_id}.1${i}
    user rancher
    proxyJump harvester-auto-host
EOF
done