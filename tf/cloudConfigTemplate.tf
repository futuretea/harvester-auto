resource "kubernetes_config_map" "password" {
  metadata {
    name      = "password"
    namespace = "default"
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
