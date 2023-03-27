resource "harvester_image" "focal-server" {
  name      = "focal-server"
  namespace = "harvester-public"

  display_name = "focal-server-cloudimg-amd64.img"
  source_type  = "download"
  url          = "http://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
}
