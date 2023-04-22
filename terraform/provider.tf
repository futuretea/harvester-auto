terraform {
  required_version = ">= 0.13"
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = "0.6.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.18.1"
    }
  }
}

provider "harvester" {
  kubeconfig = "./local.yaml"
}

provider "kubernetes" {
  config_path = "./local.yaml"
}

