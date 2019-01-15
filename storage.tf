################################################################################
# Storage
################################################################################

resource "google_storage_bucket" "dropbox" {
  name          = "lawrjone-dropbox"
  location      = "${var.region}"
  storage_class = "REGIONAL"
}
