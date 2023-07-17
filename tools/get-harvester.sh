#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    get-harvester.sh ROOTDIR VERSION BASEURL
HELP
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

ROOTDIR=$1
VERSION=$2
BASEURL=${3:-"https://releases.rancher.com/harvester"}

mkdir -p "$ROOTDIR/$VERSION"
cd "$ROOTDIR/$VERSION"

wget "${BASEURL}/${VERSION}/harvester-${VERSION}-amd64.iso"
wget "${BASEURL}/${VERSION}/harvester-${VERSION}-amd64.sha512"
wget "${BASEURL}/${VERSION}/harvester-${VERSION}-vmlinuz-amd64"
wget "${BASEURL}/${VERSION}/harvester-${VERSION}-initrd-amd64"
wget "${BASEURL}/${VERSION}/harvester-${VERSION}-rootfs-amd64.squashfs"
