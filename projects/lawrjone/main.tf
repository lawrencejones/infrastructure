################################################################################
# lawrjone: personal GCP project
################################################################################
#
# Desired state for what's still in use: the blog bucket and its deploy identity,
# personal storage buckets, Terraform state and the lawrjone.xyz zone. Rewritten in
# 2026-10 to replace projects/google, whose state had drifted (the GKE cluster it managed
# was long gone) and held service account private keys in plain text.
#
# Authenticate with your own account rather than a service account key:
#
#   gcloud auth application-default login
#
# Resources that already existed were adopted with import blocks (see git history).

terraform {
  required_version = ">= 1.5"

  backend "gcs" {
    bucket = "lawrjone-tfstate"
    prefix = "lawrjone"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}

provider "google" {
  project = local.project
  region  = local.region
}

locals {
  project = "lawrjone"
  region  = "europe-west2" # London
}

data "google_project" "current" {}

# APIs the blog deploy needs for Workload Identity Federation. Never disable on destroy:
# turning an API off can break unrelated things in the project.
resource "google_project_service" "required" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

################################################################################
# Project access
################################################################################

# Additive: other bindings on the project (Google service agents) are left alone.
resource "google_project_iam_member" "owner" {
  project = local.project
  role    = "roles/owner"
  member  = "user:lawrjone@gmail.com"
}
