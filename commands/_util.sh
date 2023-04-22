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

fetch_cherry_pick_fork() {
  local repo_name=$1
  IFS=":" read -r fork_username fork_branch <<<"$2"
  fetch_fork "${repo_name}" "${fork_username}" "${fork_branch}"
  local base_branch=$3
  git cherry-pick "origin/${base_branch}..${fork_username}-${fork_branch}"
}

fetch_checkout_fork() {
  local repo_name=$1
  IFS=":" read -r fork_username fork_branch <<<"$2"
  fetch_fork "${repo_name}" "${fork_username}" "${fork_branch}"
  git checkout "${fork_username}-${fork_branch}"
}

fetch_pr() {
  local pr_id=$1
  local pr_branch=$2
  git fetch origin "pull/${pr_id}/head:${pr_branch}"
}

fetch_merge_pr() {
  local pr_id=$1
  local pr_branch="pr-${pr_id}"
  fetch_pr "${pr_id}" "${pr_branch}"
  GIT_MERGE_AUTOEDIT=no git merge "${pr_branch}"
}

fetch_cherry_pick_pr() {
  local pr_id=$1
  local pr_branch="pr-${pr_id}"
  fetch_pr "${pr_id}" "${pr_branch}"
  local base_branch=$2
  git cherry-pick "origin/${base_branch}..${pr_branch}"
}

fetch_checkout_pr() {
  local pr_id=$1
  local pr_branch="pr-${pr_id}"
  fetch_pr "${pr_id}" "${pr_branch}"
  git checkout "${pr_branch}"
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
  local vnc_port=$((5900 + vnc_port_suffix))
  local novnc_port=$((6080 + vnc_port_suffix))
  sudo snap set novnc "services.n${novnc_port}.listen=${novnc_port}" "services.n${novnc_port}.vnc=localhost:${vnc_port}"
  echo "${novnc_port}"
}

prepare_code() {
  local repo_owner=$1
  local repo_name=$2
  local prs=$3
  local fmt_prs=$4
  local target_branch=$5
  local base_branch=$6
  shift 6
  git clone -b "${target_branch}" "$@" "https://github.com/${repo_owner}/${repo_name}.git"
  cd "${repo_name}" || exit
  git config --local user.email "harvester-auto@futuretea.me"
  git config --local user.name "harvester-auto"
  if [[ ${prs} != "0" ]]; then
    IFS=',' read -ra prs_arr <<<"${prs}"
    if [[ ${#prs_arr[@]} -eq 1 ]] && [[ "${target_branch}" == "${base_branch}" ]]; then
      if [[ "${prs}" =~ ^[0-9]+$ ]]; then
        fetch_checkout_pr "${prs}"
      else
        fetch_checkout_fork "${repo_name}" "${prs}"
      fi
    else
      git checkout -b "pr-${fmt_prs}"
      for i in "${prs_arr[@]}"; do
        if [[ "${i}" =~ ^[0-9]+$ ]]; then
          fetch_cherry_pick_pr "${i}" "${base_branch}"
        else
          fetch_cherry_pick_fork "${repo_name}" "${i}" "${base_branch}"
        fi
      done
    fi
  fi
}
