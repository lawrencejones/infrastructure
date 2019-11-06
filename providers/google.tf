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
