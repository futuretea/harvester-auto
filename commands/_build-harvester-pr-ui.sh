#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
    cat <<HELP
USAGE:
    _build-harvester-pr-ui ui_prs
HELP
}

ui_prs=${1:-"0"}

# pwd: commands
source _ui_config.sh
source _util.sh

fmt_ui_prs=$(sym2dash "${ui_prs}")

TIMESTAMP=$(date +%Y%m%d%H%M%S)
TEMPDIR=$(mktemp -d -t "harvester-auto-${TIMESTAMP}-XXXXX")
printf "TEMP_DIR=%s\n" "${TEMPDIR}"

cd "${TEMPDIR}"
# pwd: TEMPDIR

git clone https://github.com/harvester/dashboard.git
cd dashboard
# pwd: TEMPDIR/dashboard

prs="${ui_prs}"
if [[ ${prs} != "0" ]];then
  # prepare code
  IFS=',' read -ra prs_arr <<< "${prs}"
  if [[ ${#prs_arr[@]} -eq 1 ]]; then
    if [[ "${prs}" =~ ^[0-9]+$ ]];then
      fetch_checkout_pr "${prs}"
    else
      fetch_checkout_fork "dashboard" "${prs}"
    fi
  else
    git checkout -b "pr-${fmt_ui_prs}"
    for i in "${prs_arr[@]}"; do
      if [[ "${i}" =~ ^[0-9]+$ ]];then
        fetch_merge_pr "${i}"
      else
        fetch_merge_fork "dashboard" "${i}"
      fi
    done
  fi
fi

set +e
GIT_TAG=$(git tag -l --contains HEAD | head -n 1)
COMMIT_BRANCH=$(git rev-parse --abbrev-ref HEAD | sed -E 's/[^a-zA-Z0-9.-]+/-/g')
set -e
DIR=${GIT_TAG:-$COMMIT_BRANCH}
if [[ "${DIR}" == "master" ]]; then
  DIR="latest"
fi

# build dashboard
dashboard_base_url="${ui_dashboard_base_url}/${DIR}"
export BASE="${dashboard_base_url}"
./scripts/build-hosted

# upload dashboard
dashboard_output_target="${ui_dashboard_output_target}"
ossutil cp -f -r "./dist/${DIR}/" "${dashboard_output_target}/${DIR}/" --meta x-oss-object-acl:public-read

# build plugin
plugin_name="harvester"
plugin_version=$(jq -r '.version' pkg/${plugin_name}/package.json)
plugin_base_url="${ui_plugin_base_url}/${fmt_ui_prs}/${plugin_name}-${plugin_version}"
yarn build-pkg "${plugin_name}"

# upload plugin
plugin_output_target="${ui_plugin_output_target}/${fmt_ui_prs}"
ossutil cp -f -r  "./dist-pkg/${plugin_name}-${plugin_version}/" "${plugin_output_target}/${plugin_name}-${plugin_version}/" --meta x-oss-object-acl:public-read

# clean
rm -rf "${TEMPDIR}"

# output
echo "ui-index: ${dashboard_base_url}/index.html"
echo "plugin-index: ${plugin_base_url}/${plugin_name}-${plugin_version}.umd.min.js"

if [ -n "${slack_webhook_url}" ]; then
  text="build ui ${ui_prs} finished, ui-index: ${dashboard_base_url}/index.html, plugin-index: ${plugin_base_url}/index.html"
  curl -X POST -H 'Content-type: application/json' --data '{"text": "'"${text}"'"}' "${slack_webhook_url}"
fi
