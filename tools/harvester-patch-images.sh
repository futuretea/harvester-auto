#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    harvester-patch-images TARGET_REPO TARGET_TAG
HELP
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

COMMIT=$(git rev-parse --short HEAD)
SOURCE_TAG=${COMMIT}-amd64

TARGET_REPO=$1
TARGET_TAG=${2:-${SOURCE_TAG}}

function patch_harvester() {
  cat > /tmp/harvester-fix.yaml <<EOF
spec:
  values:
    containers:
      apiserver:
        image:
          repository: ${TARGET_REPO}/harvester
          tag: ${TARGET_TAG}
    webhook:
      image:
        repository: ${TARGET_REPO}/harvester-webhook
        tag: ${TARGET_TAG}
EOF
  kubectl -n fleet-local patch managedchart harvester --patch-file=/tmp/harvester-fix.yaml --type merge
  kubectl -n harvester-system scale deploy harvester --replicas=0
  kubectl -n harvester-system scale deploy harvester-webhook --replicas=0
  kubectl -n harvester-system scale deploy harvester --replicas=1
  kubectl -n harvester-system scale deploy harvester-webhook --replicas=1
}

function patch_harvester_network_controller() {
  cat > /tmp/harvester-network-controller-fix.yaml <<EOF
spec:
  values:
    harvester-network-controller:
      image:
        repository: ${TARGET_REPO}/harvester-network-controller
        tag: ${TARGET_TAG}
      webhook:
        image:
          repository: ${TARGET_REPO}/harvester-network-webhook
          tag: ${TARGET_TAG}
      helper:
        image:
          repository: ${TARGET_REPO}/harvester-network-helper
          tag: ${TARGET_TAG}
EOF
  kubectl -n fleet-local patch managedchart harvester --patch-file=/tmp/harvester-network-controller-fix.yaml --type merge
  kubectl -n harvester-system scale deploy harvester-network-controller-manager --replicas=0
  kubectl -n harvester-system scale deploy harvester-network-webhook --replicas=0
  kubectl -n harvester-system scale deploy harvester-network-controller-manager --replicas=1
  kubectl -n harvester-system scale deploy harvester-network-webhook --replicas=1
}

function patch_harvester_load_balancer() {
  cat > /tmp/harvester-load-balancer-fix.yaml <<EOF
spec:
  values:
    harvester-load-balancer:
      image:
        repository: ${TARGET_REPO}/harvester-load-balancer
        tag: ${TARGET_TAG}
EOF
  kubectl -n fleet-local patch managedchart harvester --patch-file=/tmp/harvester-load-balancer-fix.yaml --type merge
  kubectl -n harvester-system scale deploy harvester-load-balancer --replicas=0
  kubectl -n harvester-system scale deploy harvester-load-balancer --replicas=1
}

function patch_harvester_node_disk_manager() {
  cat > /tmp/harvester-node-disk-manager-fix.yaml <<EOF
spec:
  values:
    harvester-node-disk-manager:
      image:
        repository: ${TARGET_REPO}/harvester-node-disk-manager
        tag: ${TARGET_TAG}
EOF
  kubectl -n fleet-local patch managedchart harvester --patch-file=/tmp/harvester-node-disk-manager-fix.yaml --type merge
}

function patch_harvester_node_manager() {
  cat > /tmp/harvester-node-manager-fix.yaml <<EOF
spec:
  values:
    harvester-node-manager:
      image:
        repository: ${TARGET_REPO}/harvester-node-manager
        tag: ${TARGET_TAG}
EOF
  kubectl -n fleet-local patch managedchart harvester --patch-file=/tmp/harvester-node-manager-fix.yaml --type merge
}

repo_name=$(basename ${PWD})

case ${repo_name} in
harvester)
  patch_harvester
  ;;
harvester-network-controller)
  patch_harvester_network_controller
  ;;
load-balancer-harvester)
  patch_harvester_load_balancer
  ;;
harvester-load-balancer)
  patch_harvester_load_balancer
  ;;
node-disk-manager)
  patch_harvester_node_disk_manager
  ;;
harvester-node-disk-manager)
  patch_harvester_node_disk_manager
  ;;
node-manager)
  patch_harvester_node_manager
  ;;
harvester-node-manager)
  patch_harvester_node_manager
  ;;
esac