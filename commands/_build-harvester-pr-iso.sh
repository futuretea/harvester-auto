#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    build-harvester-pr-iso harvester_prs installer_prs
HELP
}

harvester_prs=${1:-"0"}
installer_prs=${2:-"0"}

source _config.sh

TIMESTAMP=$(date +%Y%m%d%H%M%S)
TEMPDIR=$(mktemp -d -t "harvester-auto-${TIMESTAMP}-XXXXX")
printf "TEMP_DIR=%s\n" "${TEMPDIR}"

replace_installer_prs() {
  local template_file=$1
  local output_file=$2
  sed "s/<installer_prs>/${installer_prs}/g" "${template_file}" >"${output_file}"
  chmod +x "${output_file}"
}

if [[ ${installer_prs} != "0" ]];then
  replace_installer_prs build-iso-with-pr.sh.tpl "${TEMPDIR}/build-iso-with-pr"
fi

cd "${TEMPDIR}"

git clone https://github.com/harvester/harvester.git
cd harvester

if [[ ${harvester_prs} != "0" ]];then
  git checkout -b pr-"${harvester_prs//,/-}"-"${installer_prs//,/-}"
  IFS=',' read -ra harvester_prs_arr <<< "${harvester_prs}"
  for i in "${harvester_prs_arr[@]}"; do
    git fetch origin "pull/${i}/head:pr-${i}"
    GIT_MERGE_AUTOEDIT=no git merge "pr-${i}"
  done
  export REPO=${REPO}
  export PUSH=true
  if [[ ! -d ".docker" ]];then
    cp ~/.docker . -r
  fi
  make
fi


if [[ ${installer_prs} != "0" ]];then
  mv ../build-iso-with-pr scripts/build-iso-with-pr
  make build-iso-with-pr
else
  make build-iso
fi

output_dir="${iso_output_dir}/${harvester_prs//,/-}-${installer_prs//,/-}/master"
mkdir -p "${output_dir}"
mv ./dist/artifacts/* "${output_dir}/"
rm -rf "${TEMPDIR}"
