################################################################################
# Backend
################################################################################

terraform {
  backend "gcs" {
    bucket = "lawrjone-tfstate"
    prefix = "terraform/state/gke"
  }
}

################################################################################
# Provider
################################################################################

provider "google" {
  region  = var.region
  version = "2.18.1"
  project = var.default_project
}

provider "google-beta" {
  region  = var.region
  version = "2.18.1"
  project = var.default_project
}

################################################################################
# Addresses
################################################################################

# Use this address for the ingress that will support the acme challenge for
# LetsEncrypt certificate management.
resource "google_compute_global_address" "acme_challenge" {
  name = "acme-challenge"
}

################################################################################
# Firewall
################################################################################

resource "google_compute_firewall" "cert_manager" {
  name        = "cert-manager"
  description = "Provide access for the API server to contact the cert-manager webhook receiving from the Kubernetes control plane"
  network     = "default"
  target_tags = ["gke-primary"]
  allow {
    protocol = "TCP"
    ports    = ["6443"]
  }

  # This is probably the GKE control plane network, but I'm not sure. There's
  # nothing else in this project right now, so being restrictive doesn't benefit
  # us.
  #
  # https://www.revsys.com/tidbits/jetstackcert-manager-gke-private-clusters/
  #
  # source_ranges = ["172.16.0.0/28"]
}

################################################################################
# GKE
################################################################################

resource "google_service_account" "gke" {
  account_id = "gke-primary"
}

# Go regional, we're gonna be big. Private cluster is also a good idea, as
# hackers are gonna be all over our thing.
resource "google_container_cluster" "primary" {
  provider = "google-beta" # 😎

  name        = "primary"
  description = "workload cluster for personal usage"
  location    = var.region

  initial_node_count       = 1    # create 3 node cluster initially
  remove_default_node_pool = true # but delete once done

  # We don't want this: RBAC all the way!
  enable_legacy_abac = false

  # We'll handle this ourselves, thanks
  logging_service    = "none"
  monitoring_service = "none"

  # Disable master authentication
  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # VPC native IP allocation
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.32.0.0/14"
    services_ipv4_cidr_block = "10.0.0.0/20"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

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

  # Allow workload identities to be bound to pods. At present, only the
  # project GKE lives within is allowed, so we set that namespace.
  workload_identity_config {
    identity_namespace = "${var.default_project}.svc.id.goog"
  }
}

resource "google_container_node_pool" "primary_01" {
  provider = "google-beta" # 😎

  name     = "primary-01"
  location = var.region
  cluster  = google_container_cluster.primary.name

  node_count = 1

  # Hands-free management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "n1-standard-2"
    preemptible  = true

    # Default is 100, but I'm pretty poor
    disk_size_gb = 30

    service_account = google_service_account.gke.email
    tags            = ["gke-primary"]

    # Scopes are crap, enable everything and use IAM
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    # If we want workload identity, we need to set this to GKE_METADATA_SERVER
    # https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }

    # It's a dev cluster, let's enable all the security
    shielded_instance_config {
      enable_secure_boot = true
    }

    # GKE 1.12 sets this by default, so if we don't set it in terraform we'll
    # get a permadiff.
    # See https://cloud.google.com/kubernetes-engine/docs/how-to/protecting-cluster-metadata#disable-legacy-apis
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
