#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    get-rke2.sh ROOTDIR VERSION
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

ROOTDIR=$1
VERSION=$2

mkdir -p $ROOTDIR/$VERSION
cd $ROOTDIR/$VERSION

wget https://github.com/rancher/rke2/releases/download/$VERSION/rke2-images.linux-amd64.tar.zst
wget https://github.com/rancher/rke2/releases/download/$VERSION/rke2-images.linux-amd64.txt
wget https://github.com/rancher/rke2/releases/download/$VERSION/rke2-images-multus.linux-amd64.txt
wget https://github.com/rancher/rke2/releases/download/$VERSION/rke2-images-harvester.linux-amd64.tar.zst
wget https://github.com/rancher/rke2/releases/download/$VERSION/rke2-images-harvester.linux-amd64.txt

# verify
wget https://github.com/rancher/rke2/releases/download/$VERSION/sha256sum-amd64.txt
sha256sum -c --ignore-missing sha256sum-amd64.txt
