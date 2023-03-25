#!/bin/bash
set -e

source $(dirname $0)/version

cd $(dirname $0)/..

echo "Start building ISO image"

HARVESTER_INSTALLER_VERSION=master

git clone --branch ${HARVESTER_INSTALLER_VERSION} --single-branch --depth 1 https://github.com/harvester/harvester-installer.git ../harvester-installer

cd ../harvester-installer

installer_prs="<installer_prs>"
IFS=',' read -ra installer_prs_arr <<< "${installer_prs}"
if [[ ${#installer_prs_arr[@]} -eq 1 ]]; then
  git fetch origin "pull/${installer_prs}/head:pr-${installer_prs}"
  git checkout "pr-${installer_prs}"
else
  git checkout -b pr-${installer_prs//,/-}
  for i in "${installer_prs_arr[@]}"; do
    git fetch origin pull/$i/head:pr-$i
    GIT_MERGE_AUTOEDIT=no git merge pr-$i
  done
fi
cd -

cd ../harvester-installer/scripts

./ci

cd ..
HARVESTER_DIR=../harvester

mkdir -p ${HARVESTER_DIR}/dist/artifacts
cp dist/artifacts/* ${HARVESTER_DIR}/dist/artifacts
