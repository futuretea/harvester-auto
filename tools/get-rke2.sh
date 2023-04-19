#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    get-rke2.sh ROOTDIR VERSION BASEURL
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

ROOTDIR=$1
VERSION=$2
BASEURL=${3:-"https://github.com/rancher/rke2/releases/download"}

mkdir -p "$ROOTDIR/$VERSION"
cd "$ROOTDIR/$VERSION"

wget "${BASEURL}/$VERSION/rke2-images.linux-amd64.tar.zst"
wget "${BASEURL}/$VERSION/rke2-images.linux-amd64.txt"
wget "${BASEURL}/$VERSION/rke2-images-multus.linux-amd64.txt"
wget "${BASEURL}/$VERSION/rke2-images-harvester.linux-amd64.tar.zst"
wget "${BASEURL}/$VERSION/rke2-images-harvester.linux-amd64.txt"

# verify
wget "${BASEURL}/$VERSION/sha256sum-amd64.txt"
sha256sum -c --ignore-missing sha256sum-amd64.txt
