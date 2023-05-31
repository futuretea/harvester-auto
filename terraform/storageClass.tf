resource "harvester_storageclass" "any-replicas-1" {
  name = "any-replicas-1"

  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = "1"
    "staleReplicaTimeout" = "30"
  }
}
