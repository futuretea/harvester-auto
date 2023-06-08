#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _build-rancher-pr-ui ui_prs
HELP
}

ui_prs=${1:-"0"}

# pwd: commands
source _ui_config.sh
source _util.sh

fmt_ui_prs=$(sym2dash "${ui_prs}")

IFS="@" read -r ui_prs ui_target_branch <<<"${ui_prs}"

if [ -z "${ui_target_branch}" ]; then
  ui_target_branch="${ui_base_branch}"
fi

echo "ui_prs: ${ui_prs}"
echo "ui_target_branch: ${ui_target_branch}"
echo "ui_base_branch: ${ui_base_branch}"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
TEMPDIR=$(mktemp -d -t "harvester-auto-${TIMESTAMP}-XXXXX")
printf "TEMP_DIR=%s\n" "${TEMPDIR}"

cd "${TEMPDIR}"
# pwd: TEMPDIR
prepare_code "rancher" "dashboard" "${ui_prs}" "${fmt_ui_prs}" "${ui_target_branch}" "${ui_base_branch}"

set +e
GIT_TAG=$(git tag -l --contains HEAD | head -n 1)
COMMIT_BRANCH=$(git rev-parse --abbrev-ref HEAD | sed -E 's/[^a-zA-Z0-9.-]+/-/g')
set -e
DIR=${GIT_TAG:-$COMMIT_BRANCH}
if [[ "${DIR}" == "master" ]]; then
  DIR="latest"
fi

# build dashboard
dashboard_base_url="${ui_rancher_dashboard_base_url}/${DIR}"
export BASE="${dashboard_base_url}"
./scripts/build-hosted

# upload dashboard
dashboard_output_target="${ui_rancher_dashboard_output_target}"
ossutil cp -f -r "./dist/${DIR}/" "${dashboard_output_target}/${DIR}/" --meta x-oss-object-acl:public-read

# clean
rm -rf "${TEMPDIR}"

# output
echo "rancher ui-index: ${dashboard_base_url}/index.html"

if [ -n "${slack_webhook_url}" ]; then
  text="build rancher ui ${ui_prs} finished, ui-index: ${dashboard_base_url}/index.html"
  curl -X POST -H 'Content-type: application/json' --data '{"text": "'"${text}"'"}' "${slack_webhook_url}"
fi
