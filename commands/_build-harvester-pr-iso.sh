#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    _build-harvester-pr-iso harvester_prs installer_prs
HELP
}

harvester_prs=${1:-"0"}
installer_prs=${2:-"0"}

# pwd: commands
source _config.sh
source _util.sh

fmt_harvester_prs=$(sym2dash "${harvester_prs}")
fmt_installer_prs=$(sym2dash "${installer_prs}")

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
  replace_installer_prs _build-iso-with-pr.sh.tpl "${TEMPDIR}/build-iso-with-pr"
  cp _util.sh "${TEMPDIR}"
fi

cd "${TEMPDIR}"
# pwd: TEMPDIR

git clone https://github.com/harvester/harvester.git
cd harvester
# pwd: TEMPDIR/harvester

prs="${harvester_prs}"
if [[ ${prs} != "0" ]];then
  # prepare code
  IFS=',' read -ra prs_arr <<< "${prs}"
  if [[ ${#prs_arr[@]} -eq 1 ]]; then
    if [[ "${prs}" =~ ^[0-9]+$ ]];then
      fetch_checkout_pr "${prs}"
    else
      fetch_checkout_fork "harvester" "${prs}"
    fi
  else
    git checkout -b "pr-${fmt_harvester_prs}"
    for i in "${prs_arr[@]}"; do
      if [[ "${i}" =~ ^[0-9]+$ ]];then
        fetch_merge_pr "${i}"
      else
        fetch_merge_fork "harvester" "${i}"
      fi
    done
  fi
fi

# build image
export REPO=${REPO:-"${default_image_repo}"}
export PUSH=true
if [[ ! -d ".docker" ]];then
  cp ~/.docker . -r
fi
make

# build iso
if [[ ${installer_prs} != "0" ]];then
  mv "${TEMPDIR}/build-iso-with-pr" scripts/
  cp "${TEMPDIR}/_util.sh" scripts/
  make build-iso-with-pr
else
  make build-iso
fi

# mv iso
output_dir="${iso_output_dir}/harvester/${fmt_harvester_prs}-${fmt_installer_prs}/master"
mkdir -p "${output_dir}"
mv ./dist/artifacts/* "${output_dir}/"

# clean
rm -rf "${TEMPDIR}"
