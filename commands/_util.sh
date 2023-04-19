#!/usr/bin/env bash

fetch_fork() {
  local repo_name=$1
  local fork_username=$2
  local fork_branch=$3
  if ! grep -q "${fork_username}" < <(git remote show); then
    git remote add "${fork_username}" "https://github.com/${fork_username}/${repo_name}.git"
  fi
  git fetch "${fork_username}" "${fork_branch}:${fork_username}-${fork_branch}"
}

fetch_merge_fork() {
  local repo_name=$1
  IFS=":" read -r fork_username fork_branch <<<"$2"
  fetch_fork "${repo_name}" "${fork_username}" "${fork_branch}"
  GIT_MERGE_AUTOEDIT=no git merge "${fork_username}-${fork_branch}"
}

fetch_checkout_fork() {
  local repo_name=$1
  IFS=":" read -r fork_username fork_branch <<<"$2"
  fetch_fork "${repo_name}" "${fork_username}" "${fork_branch}"
  git checkout "${fork_username}-${fork_branch}"
}

fetch_merge_pr() {
  local pr_id=$1
  git fetch origin "pull/${pr_id}/head:pr-${pr_id}"
  GIT_MERGE_AUTOEDIT=no git merge "pr-${pr_id}"
}

fetch_checkout_pr() {
  local pr_id=$1
  git fetch origin "pull/${pr_id}/head:pr-${pr_id}"
  git checkout "pr-${pr_id}"
}

sym2dash() {
  local src=$1
  echo "${src//[^a-zA-Z0-9]/-}"
}

get_host_ip() {
  hostname -I | awk '{print $1}'
}

get_vm_novnc_port() {
  local vm_name=$1
  local vnc_port_suffix=
  vnc_port_suffix=$(sudo virsh vncdisplay "${vm_name}" | awk -F ":" '{print $2}')
  local vnc_port=$((5900+vnc_port_suffix))
  local novnc_port=$((6080+vnc_port_suffix))
  sudo snap set novnc "services.n${novnc_port}.listen=${novnc_port}" "services.n${novnc_port}.vnc=localhost:${vnc_port}"
  echo "${novnc_port}"
}
