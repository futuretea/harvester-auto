#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    harvester-push-images TARGET_REPO TARGET_TAG
HELP
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi


COMMIT=$(git rev-parse --short HEAD)
SOURCE_TAG=${COMMIT}-amd64

SOURCE_REPO="rancher"
TARGET_REPO=$1
TARGET_TAG=${2:-${SOURCE_TAG}}

function tag_push_image() {
  local image_name=$1
  docker tag "${SOURCE_REPO}/${image_name}:${TARGET_TAG}" "${TARGET_REPO}/${image_name}:${TARGET_TAG}"
  docker push "${TARGET_REPO}/${image_name}:${TARGET_TAG}"
}

repo_name=$(basename "${PWD}")

case ${repo_name} in
harvester)
  tag_push_image harvester
  tag_push_image harvester-webhook
  ;;
harvester-network-controller)
  tag_push_image harvester-network-helper
  tag_push_image harvester-network-webhook
  tag_push_image harvester-network-controller
  ;;
cloud-provider-harvester)
  tag_push_image harvester-cloud-provider
  ;;
load-balancer-harvester)
  tag_push_image harvester-load-balancer
  ;;
node-disk-manager)
  tag_push_image node-disk-manager
  ;;
node-manager)
  tag_push_image harvester-node-manager
  ;;
esac