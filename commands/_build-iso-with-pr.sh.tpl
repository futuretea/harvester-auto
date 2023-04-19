#!/bin/bash
set -e

TOP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
SCRIPTS_DIR="${TOP_DIR}/scripts"

# shellcheck source=/dev/null
source "${SCRIPTS_DIR}/version"
# hack
source "${SCRIPTS_DIR}/_util.sh"
# end

cd "${TOP_DIR}"

echo "Start building ISO image"

HARVESTER_INSTALLER_VERSION=master

git clone --branch "${HARVESTER_INSTALLER_VERSION}" --single-branch --depth 1 https://github.com/harvester/harvester-installer.git ../harvester-installer

# hack
cd ../harvester-installer
installer_prs="<installer_prs>"
fmt_installer_prs=$(sym2dash "${installer_prs}")
prs="${installer_prs}"
if [[ ${prs} != "0" ]];then
  # prepare code
  IFS=',' read -ra prs_arr <<< "${prs}"
  if [[ ${#prs_arr[@]} -eq 1 ]]; then
    if [[ "${prs}" =~ ^[0-9]+$ ]];then
      fetch_checkout_pr "${prs}"
    else
      fetch_checkout_fork "harvester-installer" "${prs}"
    fi
  else
    git checkout -b "pr-${fmt_installer_prs}"
    for i in "${prs_arr[@]}"; do
      if [[ "${i}" =~ ^[0-9]+$ ]];then
        fetch_merge_pr "${i}"
      else
        fetch_merge_fork "harvester-installer" "${i}"
      fi
    done
  fi
fi
cd -
# end

cd ../harvester-installer/scripts

./ci

cd ..
HARVESTER_DIR=../harvester

mkdir -p "${HARVESTER_DIR}/dist/artifacts"
cp dist/artifacts/* "${HARVESTER_DIR}/dist/artifacts"
