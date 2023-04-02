#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    get-harvester.sh ROOTDIR VERSION
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

wget https://releases.rancher.com/harvester/${VERSION}/harvester-${VERSION}-amd64.iso
wget https://releases.rancher.com/harvester/${VERSION}/harvester-${VERSION}-vmlinuz-amd64
wget https://releases.rancher.com/harvester/${VERSION}/harvester-${VERSION}-initrd-amd64
wget https://releases.rancher.com/harvester/${VERSION}/harvester-${VERSION}-rootfs-amd64.squashfs

# verify
wget https://releases.rancher.com/harvester/${VERSION}/harvester-${VERSION}-amd64.sha512
# FIXME: no properly formatted SHA256 checksum lines found
#sha256sum -c --ignore-missing harvester-${VERSION}-amd64.sha512
