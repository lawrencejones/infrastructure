################################################################################
# Backend
################################################################################

terraform {
  backend "gcs" {
    bucket  = "lawrjone-tfstate"
    prefix  = "terraform/state/gke"
    project = "lawrjone"
  }
}

################################################################################
# Provider
################################################################################

provider "google" {
  region  = "${var.region}"
  version = "1.20"
  project = "${var.default_project}"
}

################################################################################
# GKE
################################################################################

data "google_compute_zones" "available" {}

# Create a zonal Kubernetes cluster. We don't need this to be HA and we're
# shooting for cheap, not always up.
resource "google_container_cluster" "primary" {
  name        = "primary"
  description = "workload cluster for personal usage"
  region      = "${var.region}"

  initial_node_count       = 1    # create 3 node cluster initially
  remove_default_node_pool = true # but delete once done

  # We don't want this: RBAC all the way!
  enable_legacy_abac = false

  # It's not clear whether network policies are enabled by default, so
  # explicitly turn them on
  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }
}

resource "google_container_node_pool" "primary_01" {
  name    = "primary-01"
  region  = "${var.region}"
  cluster = "${google_container_cluster.primary.name}"

  node_count = 1

  node_config {
    machine_type = "n1-standard-2"
    preemptible  = true
  }
}
