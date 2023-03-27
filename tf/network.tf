data "harvester_clusternetwork" "mgmt" {
  name = "mgmt"
}
resource "harvester_network" "mgmt-vlan1" {
  name      = "mgmt-vlan1"
  namespace = "harvester-public"

  vlan_id = 1

  route_mode           = "auto"
  route_dhcp_server_ip = ""

  cluster_network_name = data.harvester_clusternetwork.mgmt.name
}
