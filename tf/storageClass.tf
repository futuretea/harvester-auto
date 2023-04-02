resource "kubernetes_storage_class" "replicas-1" {
  metadata {
    name = "replicas-1"
  }
  storage_provisioner = "driver.longhorn.io"
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"
  parameters          = {
    "migratable"          = "true"
    "numberOfReplicas"    = "1"
    "staleReplicaTimeout" = "30"
  }
}
