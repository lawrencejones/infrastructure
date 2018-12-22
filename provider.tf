################################################################################
# Bootstrap
################################################################################

provider "google" {
  region  = "europe-west2" # London
  version = "1.20"
}

resource "google_project" "lawrjone" {
  name            = "lawrjone"
  project_id      = "206046083972"
  billing_account = "0111E6-7594C9-346E51"
}
