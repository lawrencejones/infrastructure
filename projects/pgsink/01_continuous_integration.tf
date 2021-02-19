################################################################################
# Project
################################################################################

# Create a project exclusively for pgsink CI resources, which will be connected
# to CircleCI for testing.
resource "google_project" "pgsink_ci" {
  name                = "lawrjone-pgsink-ci"
  project_id          = "lawrjone-pgsink-ci"
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "bigquery" {
  service = "bigquery.googleapis.com"
  project = google_project.pgsink_ci.project_id
}
