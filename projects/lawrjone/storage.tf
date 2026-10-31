################################################################################
# Private storage
################################################################################

# Personal backups. Private: only project owners can read it.
resource "google_storage_bucket" "dropbox" {
  name                        = "lawrjone-dropbox"
  location                    = "EUROPE-WEST2"
  storage_class               = "REGIONAL"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

# Terraform state for every project in this repository. Versioned, so a bad apply can be
# rolled back, and never public.
resource "google_storage_bucket" "tfstate" {
  name                        = "lawrjone-tfstate"
  location                    = "EUROPE-WEST2"
  storage_class               = "REGIONAL"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # Keep the last 10 versions of each state file.
  lifecycle_rule {
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}

# With uniform bucket-level access, object ACLs no longer apply, and the default bucket
# bindings (legacyBucketOwner) don't include reading objects. Without this, project owners
# can list these buckets but not read what's in them, including Terraform's own state.
resource "google_storage_bucket_iam_member" "owners_object_admin" {
  for_each = {
    dropbox = google_storage_bucket.dropbox.name
    tfstate = google_storage_bucket.tfstate.name
  }

  bucket = each.value
  role   = "roles/storage.objectAdmin"
  member = "projectOwner:${local.project}"
}

################################################################################
# DNS
################################################################################

resource "google_dns_managed_zone" "lawrjone_xyz" {
  name        = "lawrjone"
  dns_name    = "lawrjone.xyz."
  description = "Non-public facing websites"
}
