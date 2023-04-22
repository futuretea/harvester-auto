#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _build-harvester-pr-iso harvester_prs installer_prs

  e.g.
    _build-harvester-pr-iso

    _build-harvester-pr-iso 3814 480
    _build-harvester-pr-iso 3814 480@v1.1
    _build-harvester-pr-iso 3814@v1.1 480
    _build-harvester-pr-iso 3814@v1.1 480@v1.1
    _build-harvester-pr-iso harvester:v1.1 harvester:v1.1
    _build-harvester-pr-iso 3814,futuretea:multi-csi@v1.1 480@v1.1
HELP
}

harvester_prs=${1:-"0"}
installer_prs=${2:-"0"}

# pwd: commands
source _config.sh
source _util.sh

fmt_harvester_prs=$(sym2dash "${harvester_prs}")
fmt_installer_prs=$(sym2dash "${installer_prs}")

IFS="@" read -r harvester_prs harvester_target_branch <<<"${harvester_prs}"
IFS="@" read -r installer_prs installer_target_branch <<<"${installer_prs}"

if [ -z "${harvester_target_branch}" ]; then
  harvester_target_branch="${backend_base_branch}"
fi

if [ -z "${installer_target_branch}" ]; then
  installer_target_branch="${backend_base_branch}"
fi

echo "harvester_prs: ${harvester_prs}"
echo "harvester_target_branch: ${harvester_target_branch}"
echo "installer_prs: ${installer_prs}"
echo "installer_target_branch: ${installer_target_branch}"
echo "fmt_harvester_prs: ${fmt_harvester_prs}"
echo "fmt_installer_prs: ${fmt_installer_prs}"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
TEMPDIR=$(mktemp -d -t "harvester-auto-${TIMESTAMP}-XXXXX")
printf "TEMP_DIR=%s\n" "${TEMPDIR}"

replace_installer_build_iso() {
  local template_file=$1
  local output_file=$2
  jinja2 "${template_file}" \
    -D backend_base_branch="${backend_base_branch}" \
    -D installer_target_branch="${installer_target_branch}" \
    -D installer_prs="${installer_prs}" \
    -D fmt_installer_prs="${fmt_installer_prs}" > "${output_file}"
  chmod +x "${output_file}"
}

if [[ ${installer_prs} != "0" ]]; then
  replace_installer_build_iso _build-iso-with-pr.sh.j2 "${TEMPDIR}/build-iso-with-pr"
  cp _util.sh "${TEMPDIR}"
fi

cd "${TEMPDIR}"
# pwd: TEMPDIR

prepare_code "harvester" "harvester" "${harvester_prs}" "${fmt_harvester_prs}" "${harvester_target_branch}" "${backend_base_branch}"
# pwd: TEMPDIR/harvester

# build image
export REPO=${REPO:-"${default_image_repo}"}
export PUSH=true
if [[ ! -d ".docker" ]]; then
  cp ~/.docker . -r
fi
make

# build iso
if [[ ${installer_prs} != "0" ]]; then
  mv "${TEMPDIR}/build-iso-with-pr" scripts/
  cp "${TEMPDIR}/_util.sh" scripts/
  RKE2_IMAGE_REPO=${rke2_image_repo} make build-iso-with-pr
else
  RKE2_IMAGE_REPO=${rke2_image_repo} make build-iso
fi

# upload iso to minio
mc cp ./dist/artifacts/* "${harvester_iso_upload_oss_alias}/${harvester_iso_upload_bucket_name}/${fmt_harvester_prs}-${fmt_installer_prs}/master/"

# clean
rm -rf "${TEMPDIR}"
