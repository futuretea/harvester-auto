#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    _upgrade-harvester.sh harvester_url harvester_version namespace_id cluster_id
    __upgrade-harvester.sh https://releases.rancher.com/harvester master 1 1
HELP
}

if [ $# -lt 4 ]; then
  usage
  exit 1
fi

harvester_url=$1
harvester_version=$2
namespace_id=$3
cluster_id=$4
cluster_name="harvester-${namespace_id}-${cluster_id}"

source _config.sh

workspace_cluster="${workspace_root}/${cluster_name}"
workspace="${workspace_cluster}/harvester-auto"
kubeconfig_file="${workspace_cluster}/kubeconfig"

mkdir -p "${workspace}/upgrade"
cd "${workspace}/upgrade"

# patch system-upgrade-controller
patch_timeout=3600
cat > upgrade-fix.yaml <<EOF
spec:
  values:
    systemUpgradeJobActiveDeadlineSeconds: "${patch_timeout}"
EOF

kubectl --kubeconfig="${kubeconfig_file}" -n fleet-local patch managedcharts.management.cattle.io local-managed-system-upgrade-controller --patch-file=upgrade-fix.yaml --type merge
kubectl --kubeconfig="${kubeconfig_file}" -n cattle-system rollout restart deploy/system-upgrade-controller
kubectl --kubeconfig="${kubeconfig_file}" -n cattle-system wait --for=condition=Available deploy system-upgrade-controller
kubectl --kubeconfig="${kubeconfig_file}" -n cattle-system wait --for=jsonpath='{.data.SYSTEM_UPGRADE_JOB_ACTIVE_DEADLINE_SECONDS}'="${patch_timeout}" cm system-upgrade-controller-config

# patch server-version
server_version=$(kubectl --kubeconfig="${kubeconfig_file}" get setting server-version -o jsonpath='{.value}')
if [[ ! "${server_version}" == "v"* ]]; then
  cat > server-version.yaml <<EOF
  value: ${default_upgrade_from_version}
EOF
  kubectl --kubeconfig="${kubeconfig_file}" patch setting server-version --patch-file=server-version.yaml --type merge
fi

# get iso sha512sum from url
iso_file_url="${harvester_url}/${harvester_version}/harvester-${harvester_version}-amd64.iso"
sha512_file_url="${harvester_url}/${harvester_version}/harvester-${harvester_version}-amd64.sha512"
iso_check_sum=$(curl -s "${sha512_file_url}" | head -n 1 | awk '{print $1}')
release_date=$(date +"%Y%m%d")

# create version from iso
upgrade_to_version="${harvester_version}"
if [[ ! "${harvester_version}" == "v"* ]]; then
  upgrade_to_version="${default_upgrade_to_version}"
fi

cat > version.yaml <<EOF
apiVersion: harvesterhci.io/v1beta1
kind: Version
metadata:
  name: ${upgrade_to_version}
  namespace: harvester-system
spec:
  isoChecksum: "${iso_check_sum}"
  isoURL: "${iso_file_url}"
  releaseDate: "${release_date}"
EOF

kubectl --kubeconfig="${kubeconfig_file}" apply -f version.yaml

# clean existing upgrade
kubectl --kubeconfig="${kubeconfig_file}" -n harvester-system delete upgrades.harvesterhci.io --all

if [ -n "${slack_webhook_url}" ]; then
  text="upgrade version ${upgrade_to_version} for cluster ${cluster_id} in namespace ${namespace_id} added"
  curl -X POST -H 'Content-type: application/json' --data '{"text": "'"${text}"'"}' "${slack_webhook_url}"
fi
