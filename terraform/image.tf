resource "harvester_image" "focal-server" {
  name      = "focal-server"
  namespace = "harvester-public"

  storage_class_name = harvester_storageclass.any-replicas-1.name

  display_name = "focal-server-cloudimg-amd64.img"
  source_type  = "download"
  url          = var.ubuntu_image_url
}
