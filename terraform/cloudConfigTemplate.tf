resource "kubernetes_config_map" "password" {
  metadata {
    name      = "password"
    namespace = "harvester-public"
    labels = {
      "harvesterhci.io/cloud-init-template" : "user"
    }
  }

  data = {
    cloudInit = <<-EOF
      #cloud-config
      password: password
      chpasswd:
        expire: false
      ssh_pwauth: true
      EOF
  }
}

resource "kubernetes_config_map" "ubuntu-mirror-and-password" {
  metadata {
    name      = "ubuntu-mirror-and-password"
    namespace = "harvester-public"
    labels = {
      "harvesterhci.io/cloud-init-template" : "user"
    }
  }

  data = {
    cloudInit = <<-EOF
      #cloud-config
      apt:
        primary:
        - arches: [default]
          uri: ${var.ubuntu_mirror_url}
      password: password
      chpasswd:
        expire: false
      ssh_pwauth: true
      EOF
  }
}

resource "kubernetes_config_map" "docker-rancher" {
  metadata {
    name      = "docker-rancher"
    namespace = "harvester-public"
    labels = {
      "harvesterhci.io/cloud-init-template" : "user"
    }
  }

  data = {
    cloudInit = <<-EOF
      #cloud-config
      apt:
        primary:
        - arches: [default]
          uri: ${var.ubuntu_mirror_url}
      password: password
      chpasswd:
        expire: false
      ssh_pwauth: true
      package_update: true
      packages:
        - qemu-guest-agent
      runcmd:
        - - systemctl
          - enable
          - --now
          - qemu-guest-agent.service
        - "curl -sL https://releases.rancher.com/install-docker/20.10.sh | bash -"
        - "sudo systemctl enable --now docker"
        - "docker run -itd --name rancher --privileged=true --restart=unless-stopped -p 443:443 -p 80:80 rancher/rancher:v2.7-head"
      EOF
  }
}