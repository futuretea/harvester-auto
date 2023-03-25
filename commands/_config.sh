#!/usr/bin/env bash
workspace_root="/workspace"
logs_dir="/workspace/logs"
git_repo_name="harvester-auto"
git_repo_branch="master"
git_repo_url="https://github.com/futuretea/harvester-auto"
iso_output_dir="/var/www/html"
default_iso_download_url="https://releases.rancher.com/harvester"
default_image_repo="127.0.0.1:88/rancher"
default_node_number=2
default_cpu_count=8
default_memory_size=16384
default_disk_size=150G
# should keep the same with the default password in settings.yml.j2
default_node_password="p@ssword"