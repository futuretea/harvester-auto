resource "harvester_image" "focal-server" {
  name      = "focal-server"
  namespace = "harvester-public"

  display_name = "focal-server-cloudimg-amd64.img"
  source_type  = "download"
  url          = "${var.ubuntu_image_url}"
}
