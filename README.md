# harvester-auto

Create a Harvester Cluster with a single slack command.

## Features

- [x] Multi-User
- [x] Multi-Namespace
- [x] Multi-Cluster
- [x] Multi-Node-Per-Cluster
- [x] Multi-Disk-Per-Node
- [x] Multi-NIC-Per-Node
- [x] Multi-Repo
- [x] Multi-Branch
- [x] Auto-Download-Release
- [x] Auto-Build-ISO
- [x] Auto-Deploy-Cluster
- [x] Auto-Init-Cluster
- [x] Auto-Build-Push-UI
- [x] Auto-Build-Push-Patch-Image
- [x] Auto-Notification
- [x] Auto-Upgrade
- [ ] Auto-Test

## Architecture

![architecture](./asserts/architecture.png)

## Environment

### Node Setup

#### Vagrant Libvirt

```bash
sudo apt purge vagrant-libvirt
sudo apt-mark hold vagrant-libvirt
sudo apt update
sudo apt install -y qemu libvirt-daemon-system ebtables libguestfs-tools vagrant ruby-fog-libvirt
vagrant plugin install vagrant-libvirt
```

Create 4 pools to store virtual disks. In order to improve performance and stability, it is recommended that different pools correspond to different underlying physical nvme disks
```bash
create_pool(){
	local pool_name=$1
	local pool_target=$2
	virsh pool-define-as $1 dir --target $2
	virsh pool-autostart $1
	virsh pool-start $1
}
create_pool pool1 /var/lib/libvirt/images/pool1
create_pool pool2 /var/lib/libvirt/images/pool2
create_pool pool3 /var/lib/libvirt/images/pool3
create_pool pool4 /var/lib/libvirt/images/pool4
```

#### Docker

```bash
curl -sL https://releases.rancher.com/install-docker/20.10.sh | bash -
sudo systemctl enable --now docker
```

#### Proxy

Since the Harvester nodes created use a private network, all are only accessible on the host node. In order to access
the Harvester UI remotely and use kubectl to manage the cluster, running a socks5 proxy server on the host

```bash
# refer to https://github.com/serjs/socks5-server
sudo docker run -d --name socks5 --restart=unless-stopped -p 1080:1080 serjs/go-socks5-proxy
```

#### NoVNC

```bash
sudo snap install novnc
```

#### WebSSH

```bash
# refer to https://github.com/huashengdun/webssh
sudo docker run -d --name wssh --restart=unless-stopped -p 8888:8888 futuretea/wssh
```

#### WebTail

```bash
# refer to https://github.com/LeKovr/webtail
logs_dir="/workspace/logs"
sudo docker run -d --name webtail --restart=unless-stopped -p 8080:8080 -v ${logs_dir}:/mnt ghcr.io/lekovr/webtail --root /mnt
```

#### Nodejs
Use Nodejs to build the UI

- Refer to the documentation https://computingforgeeks.com/install-node-js-14-on-ubuntu-debian-linux/ to install nodejs

#### Tools
Some tools are required to run the scripts.

```bash
sudo apt install -y ansible sshpass jq
sudo pip install jinja2-cli
sudo snap install yq
sudo snap install task --classic
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
# helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
# terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
````

### Dependent service
Use the following LAN services to speed up the build process.

#### MinIO
Use MinIO to serve the built ISO files.

- Refer to the documentation https://min.io/download to install minio
- create a `harvester-iso` bucket
- download minio client `mc`

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
mv mc /usr/local/bin/
```
- set alias
```bash
mc alias set myminio <minio url> <minio access key> <minio secret key>
```

- set policy
```bash
mc anonymous set download myminio/harvester-iso
```

#### Harbor
Use Harbor to serve the built docker images.

- Refer to the documentation https://goharbor.io/ to install Harbor
- create a `rancher` project
- docker login

```bash
docker login <Harbor domain>
```

## Usage

### Preparing your Slack App

Refer to https://github.com/shomali11/slacker#preparing-your-slack-app

### Clone

```bash
git clone https://github.com/futuretea/harvester-auto.git
cd harvester-auto
```

### Configure

Change the dns nameserver address and image repo configurations in `./commands/_config.sh`

```bash
cd commands
cp _config.sh.example _config.sh
vim _config.sh
cd -
```

Fill in the Slack app token and user configurations in `./configs/config.yaml`

```bash
cd configs
cp config.yaml.example config.yaml
vim config.yaml
cd -
```

### Build

```bash
task go:build
mv ./bin/harvester-auto .
```

### Run for testing

```bash
./harvester-auto
```

### Run in background

```bash
cat > /tmp/harvester-auto.service <<EOF
[Unit]
Description=Harvester Auto Service
After=network.target

[Service]
Type=simple
User=${USER}
Restart=on-failure
RestartSec=5s
ExecStart=${PWD}/harvester-auto
WorkingDirectory=${PWD}

[Install]
WantedBy=multi-user.target
EOF
sudo cp /tmp/harvester-auto.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now harvester-auto
```

### Update

```bash
task update
```

### Send commands from slack

Send `help` to the Slack app to get the help message

#### PRs format in commands

1. A number `0` means no PRs
2. A number greater than 0 means the PR number, e.g. `123` means the PR `123`
3. A string means a branch name in fork repo, e.g. `futuretea:dev` means the branch `dev` in user `futuretea`'s fork repo
4. Support multiple PRs or branches, separated by comma, e.g. `123,456,futuretea:dev`
5. Support backport PRs, e.g. `123@v1.1` means backport PR `123` to branch `v1.1`

A complete example: `123,futuretea:dev@v1.1` will:
- Checkout the base branch, default to `master`
- Create a base branch named `pr-123-futuretea-dev-v1-1` from the base master
- Backport PR `123` to branch `v1.1`, cherry-pick the changes
- Backport branch `dev` in user `futuretea`'s fork repo to branch `v1.1`, cherry-pick the changes

#### Commands

- help - help

- ping - Ping! `*`
  > Example: ping

- history `historyNumber` - Show history `*`
  > Example: history

  > Example: history 100

- l - List Harvester clusters `*`
  > Example: l

- c `clusterID` - Show/Set Current Harvester cluster `*`
  > Example: c (show current cluster id)

  > Example: c 1 (set current cluster id to 1)

- status - Show Harvester cluster status `*`
  > Example: status

- url - Show Harvester cluster URLs `*`
  > Example: url

- version - Show Harvester version `*`
  > Example: version

- name `name` - Show/Set Harvester name `*`
  > Example: name

  > Example: name test-cluster

- settings - Show Harvester settings `*`
  > Example: settings

- pis `kubeNamespace` - Show Pod Images `*`
  > Example: pis

  > Example: pis cattle-system

- pods  `kubeNamespace` - Show Pods `*`
  > Example: pods

  > Example: pods cattle-system

- vms  `kubeNamespace` - Show VMs `*`
  > Example: vms

  > Example: vms harvester-public

- settings - Show Harvester settings `*`
  > Example: settings

- kubeconfig - Show Harvester cluster kubeconfig content `*`
  > Example: kubeconfig

- sshconfig - Show ssh config for connecting `*`
  > Example: sshconfig

- destroy - Destroy Harvester cluster nodes `*`
  > Example: destroy

- start - Start Harvester cluster nodes `*`
  > Example: start

- restart - Restart Harvester cluster nodes `*`
  > Example: restart

- stop - Stop Harvester cluster nodes `*`
  > Example: stop

- snaps - List Harvester cluster snapshots `*`
  > Example: snaps

- snap - Snapshot Harvester cluster nodes `*`
  > Example: snap 1node

  > Example: snap 3node

- revert - Revert Harvester cluster nodes `*`
  > Example: revert 1node

  > Example: revert 3node

- virsh `command` `args` - virsh command warpper `*`
  > Example: virsh list

- ps - Show running jobs `*`
  > Example: ps

- log `job` `lineNumber` - Tail Job logs `*`
  > Example: log 2c

  > Example: log 2c 100

  > Example: log 2ui

  > Example: log 2ui 100

  > Example: log 2pt

  > Example: log 2pt 100

  > Example: log 2iso

  > Example: log 2iso 100

  > Example: log sc

  > Example: log sc 100

  > Example: log up

  > Example: log up 100

- kill `job` - Kill running job `*`
  > Example: kill 2c

  > Example: kill 2pt

  > Example: kill 2iso

  > Example: kill 2ui

  > Example: kill sc

  > Example: kill up

- pr2iso `harvesterPRs` `harvesterInstallerPRs` - Build Harvester iso after merging PRs or
  checkout branches `*`
  > Example: pr2iso 0 0

- pr2c `harvesterPRs` `harvesterInstallerPRs` `harvesterConfigURL` - Create a Harvester cluster after merging PRs or
  checkout branches, always build ISO `*`
  > Example: pr2c 0 0

- pr2cNoBuild `harvesterPRs` `harvesterInstallerPRs` `harvesterConfigURL` - Create a Harvester cluster based on PRs or
  branches, but use the built ISO from pr2c `*`
  > Example: pr2cNoBuild 0 0

- v2c `harvesterVersion` `harvesterConfigURL` - Create a Harvester cluster after downloading the ISO *
  > Example: v2c v1.1.1

- pr2up `harvesterPRs` `harvesterInstallerPRs` - Upgrade a Harvester cluster after merging PRs or
  checkout branches, always build ISO `*`
  > Example: pr2up 0 0

- pr2upNoBuild `harvesterPRs` `harvesterInstallerPRs` - Upgrade a Harvester cluster based on PRs or
  branches, but use the built ISO from pr2c `*`
  > Example: pr2upNoBuild 0 0

- v2up `harvesterVersion` - Upgrade a Harvester cluster after downloading the ISO *
  > Example: v2up v1.1.2-rc5

- scale `nodeNumber` - Scale Harvester nodes *
  > Example: scale 2

  > Example: scale 3

- pr2ui `uiPRs` - Build Harvester Dashboard `*`
  > Example: pr2ui 0

- pr2pt `repoName` `repoPRs` - Patch Harvester image after merging PRs or checkout branches, always build image `*`
  > Example: pr2pt harvester 0

`* Authorized users only`
