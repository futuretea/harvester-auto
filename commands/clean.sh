#!/usr/bin/env bash
[[ -n $DEBUG ]] && set -x
set -eou pipefail

usage() {
  cat <<HELP
USAGE:
    clean.sh 
HELP
}

if [ $# -lt 0 ]; then
  usage
  exit 1
fi

docker images | grep harvester | grep -v none | awk '{print "docker rmi "$1":"$2}' | bash
docker system prune -f
docker volume prune -f
docker image prune -f
rm -rf /var/www/html/harvester/*
