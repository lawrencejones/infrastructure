################################################################################
# blog.lawrencejones.dev
################################################################################

resource "google_storage_bucket" "blog" {
  name          = "blog.lawrencejones.dev"
  location      = "${var.region}"
  storage_class = "REGIONAL"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

resource "google_service_account" "blog_deployer" {
  account_id = "blog-deployer"
}

resource "google_service_account_key" "blog_deployer_circleci" {
  service_account_id = "${google_service_account.blog_deployer.name}"
}

# Deployment is about syncing assets to GCS, so we'll need objectAdmin
resource "google_storage_bucket_iam_member" "blog_deployer_storage_admin" {
  bucket = "${google_storage_bucket.blog.name}"
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.blog_deployer.email}"
}

# This bucket should be open to the world so that GCS can correctly serve the
# assets.
resource "google_storage_bucket_iam_member" "blog_all_storage_viewer" {
  bucket = "${google_storage_bucket.blog.name}"
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
