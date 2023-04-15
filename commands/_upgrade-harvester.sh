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
kubeconfig_file="${logs_dir}/${cluster_name}.kubeconfig"

workspace_cluster="${workspace_root}/${cluster_name}"
workspace="${workspace_cluster}/harvester-auto"

mkdir -p "${workspace}/upgrade"
cd "${workspace}/upgrade"

wget -nc "${harvester_url}/${harvester_version}/harvester-${harvester_version}-amd64.iso"
iso_local_file="harvester-${harvester_version}-amd64.iso"
iso_check_sum=$(sha512sum "${iso_local_file}" | awk '{print $1}')
release_date=$(date +"%Y%m%d")

server_version=$(kubectl --kubeconfig=${kubeconfig_file} get setting server-version -o jsonpath='{.value}')
if [[ ! "${server_version}" == "v"* ]]; then
  cat > server-version.yaml <<EOF
  value: ${default_upgrade_from_version}
EOF
  kubectl --kubeconfig=${kubeconfig_file} patch setting server-version --patch-file=server-version.yaml --type merge
  kubectl --kubeconfig=${kubeconfig_file} -n harvester-system scale deploy harvester --replicas=0
  kubectl --kubeconfig=${kubeconfig_file} -n harvester-system scale deploy harvester --replicas=1
  kubectl --kubeconfig=${kubeconfig_file} -n harvester-system wait --for=condition=Available deploy harvester
fi

upgrade_to_version=${harvester_version}
if [[ ! "${harvester_version}" == "v"* ]]; then
  upgrade_to_version=${default_upgrade_to_version}
fi

cat > version.yaml <<EOF
apiVersion: harvesterhci.io/v1beta1
kind: Version
metadata:
  name: ${upgrade_to_version}
  namespace: harvester-system
spec:
  isoChecksum: "${iso_check_sum}"
  isoURL: ${harvester_url}/${harvester_version}/harvester-${harvester_version}-amd64.iso
  releaseDate: "${release_date}"
EOF

kubectl --kubeconfig=${kubeconfig_file} apply -f version.yaml

cat > upgrade.yaml <<EOF
apiVersion: harvesterhci.io/v1beta1
kind: Upgrade
metadata:
  name: hvst-upgrade-auto
  namespace: harvester-system
spec:
  version: ${harvester_version}
EOF
kubectl --kubeconfig=${kubeconfig_file} -n harvester-system delete upgrades.harvesterhci.io --all
kubectl --kubeconfig=${kubeconfig_file} apply -f upgrade.yaml

cat > upgrade-fix.yaml <<EOF
spec:
  values:
    systemUpgradeJobActiveDeadlineSeconds: "3600"
EOF

kubectl --kubeconfig=${kubeconfig_file} -n fleet-local patch managedcharts.management.cattle.io local-managed-system-upgrade-controller --patch-file=upgrade-fix.yaml --type merge
kubectl --kubeconfig=${kubeconfig_file} -n cattle-system rollout restart deploy/system-upgrade-controller
kubectl --kubeconfig=${kubeconfig_file} -n cattle-system wait --for=condition=Available deploy system-upgrade-controller

kubectl --kubeconfig=${kubeconfig_file} -n harvester-system wait --for=condition=LogReady Upgrade hvst-upgrade-auto --timeout=30m
echo "LogReady"

kubectl --kubeconfig=${kubeconfig_file} -n harvester-system wait --for=condition=ImageReady Upgrade hvst-upgrade-auto --timeout=30m
echo "ImageReady"

kubectl --kubeconfig=${kubeconfig_file} -n harvester-system wait --for=condition=RepoReady Upgrade hvst-upgrade-auto --timeout=30m
echo "RepoReady"

kubectl --kubeconfig=${kubeconfig_file} -n harvester-system wait --for=condition=Completed Upgrade hvst-upgrade-auto --timeout=180m
echo "Completed"

if [ -n "${slack_webhook_url}" ]; then
  text="upgrade cluster ${cluster_id} in namespace ${namespace_id} started"
  curl -X POST -H 'Content-type: application/json' --data '{"text": "'"${text}"'"}' "${slack_webhook_url}"
fi
