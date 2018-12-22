################################################################################
# Backend
################################################################################

# If creating these resources from scratch, the given GCS bucket isn't going to
# be available. Comment the backend configuration and use local storage
# temporarily to run the root terraform project (please README bootstrap steps).
# Once complete terraform should be able to pull its state file and continue.

terraform {
  backend "gcs" {
    bucket  = "lawrjone-tfstate"
    prefix  = "terraform/state"
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

resource "google_project" "lawrjone" {
  name            = "lawrjone"
  project_id      = "206046083972"
  billing_account = "${var.billing_account}"
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
