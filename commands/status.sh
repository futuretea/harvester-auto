#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    status.sh namespace_id cluster_id
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
source _util.sh
host_ip=$(get_host_ip)
echo "Cluster        Node        State        Display"
echo "-------------------------------------------------"

for vm in $(sudo virsh -q list --all | awk '{print $2}'); do
  if [[ ! "${vm}" =~ harvester-auto_${cluster_name} ]]; then
    continue
  fi
  vm_no_prefix="${vm#harvester-auto_${cluster_name}-}"
  vnc_port_suffix=$(sudo virsh vncdisplay "${vm}" | awk -F ":" '{print $2}')
  vnc_port=$((5900+${vnc_port_suffix}))
  novnc_port=$((6080+${vnc_port_suffix}))
  sudo snap set novnc services.n${novnc_port}.listen=${novnc_port} services.n${novnc_port}.vnc=localhost:${vnc_port}
  state=$(sudo virsh domstate "${vm}")
  echo "${cluster_id}   ${vm_no_prefix}   ${state}   http://${host_ip}:${novnc_port}/vnc.html"
done
