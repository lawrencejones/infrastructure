################################################################################
# Backend
################################################################################

# If creating these resources from scratch, the given GCS bucket isn't going to
# be available. Comment the backend configuration and use local storage
# temporarily to run the root terraform project (please README bootstrap steps).
# Once complete terraform should be able to pull its state file and continue.

terraform {
  backend "gcs" {
    bucket = "lawrjone-tfstate"
    prefix = "terraform/state"
  }
}

################################################################################
# Project
################################################################################

resource "google_project" "default" {
  name            = "${var.default_project}"
  project_id      = "206046083972"
  billing_account = "${var.billing_account}"
}

resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "cloudresourcemanager" {
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "container" {
  service = "container.googleapis.com"
}

resource "google_project_service" "storage" {
  service = "storage-api.googleapis.com"
}

resource "google_project_service" "cloudbilling" {
  service = "cloudbilling.googleapis.com"
}

resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
}

resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
}

resource "google_project_service" "cloudkms" {
  service = "cloudkms.googleapis.com"
}

################################################################################
# Terraform
################################################################################

resource "google_service_account" "terraform" {
  account_id   = "terraform"
  display_name = "terraform administrator account"
}

resource "google_storage_bucket" "tfstate" {
  name          = "lawrjone-tfstate"
  location      = "europe-west2"
  storage_class = "REGIONAL"
}

################################################################################
# IAM
################################################################################

# Permit these users to access IAP protected resources
resource "google_project_iam_binding" "iap" {
  role = "roles/iap.httpsResourceAccessor"

  members = [
    "user:lawrjone@gmail.com",
    "user:lawrence@gocardless.com",
  ]
}

# Permit Dyson to administrate this project while we pair
resource "google_project_iam_member" "owner" {
  role   = "roles/owner"
  member = "user:dyson@gocardless.com"
}

################################################################################
# Storage
################################################################################

resource "google_storage_bucket" "dropbox" {
  name          = "lawrjone-dropbox"
  location      = "${var.region}"
  storage_class = "REGIONAL"
}

################################################################################
# Networking
################################################################################

# This project contains machines that only have private interfaces. Provision
# Cloud NAT to enable these machines to reach externally.

data "google_compute_network" "default" {
  name = "default"
}

resource "google_compute_router" "default" {
  name    = "default"
  network = data.google_compute_network.default.name
}

resource "google_compute_router_nat" "egress" {
  name   = "egress"
  router = google_compute_router.default.name
  region = var.region

  # We don't need to whitelist anything in this project, so we don't need to
  # manage the IP addresses.
  nat_ip_allocate_option = "AUTO_ONLY"

  # Allow any resource within this project to reach out via Cloud NAT
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
