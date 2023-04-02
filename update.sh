#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    update.sh 
HELP
}

git pull
make
sudo systemctl stop harvester-auto
mv ./bin/harvester-auto .
sudo systemctl start harvester-auto
