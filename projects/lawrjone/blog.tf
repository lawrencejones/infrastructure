################################################################################
# blog.lawrencejones.dev
################################################################################
#
# Static site served from GCS through Cloudflare (DNS in projects/lawrencejones.dev).
# GitHub Actions in lawrencejones/blog.lawrencejones.dev syncs the built site here.

resource "google_storage_bucket" "blog" {
  name          = "blog.lawrencejones.dev"
  location      = "EUROPE-WEST2"
  storage_class = "REGIONAL"

  # Access is decided by IAM alone; no per-object ACLs can make something public.
  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

# The public may fetch objects by name but not list the bucket. roles/storage.objectViewer
# (the previous grant) includes storage.objects.list, which let anyone enumerate every file.
resource "google_project_iam_custom_role" "public_object_reader" {
  role_id     = "publicObjectReader"
  title       = "Public object reader"
  description = "Read objects by name, without listing. For public static sites."
  permissions = ["storage.objects.get"]
}

# Authoritative: these are the only bindings on the bucket. Anything else, including the
# old allUsers objectViewer grant, is removed on apply.
data "google_iam_policy" "blog" {
  binding {
    role    = google_project_iam_custom_role.public_object_reader.id
    members = ["allUsers"]
  }

  binding {
    role    = "roles/storage.objectAdmin"
    members = ["serviceAccount:${google_service_account.blog_deployer.email}"]
  }

  # Keep the defaults GCS gives every bucket, so project owners can still manage it.
  binding {
    role    = "roles/storage.legacyBucketOwner"
    members = ["projectOwner:${local.project}", "projectEditor:${local.project}"]
  }

  # The deployer needs storage.buckets.get too: gcloud storage rsync reads the bucket
  # before syncing, and objectAdmin only covers objects.
  binding {
    role = "roles/storage.legacyBucketReader"
    members = [
      "projectViewer:${local.project}",
      "serviceAccount:${google_service_account.blog_deployer.email}",
    ]
  }
}

resource "google_storage_bucket_iam_policy" "blog" {
  bucket      = google_storage_bucket.blog.name
  policy_data = data.google_iam_policy.blog.policy_data
}

################################################################################
# Deploys from GitHub Actions
################################################################################

resource "google_service_account" "blog_deployer" {
  account_id   = "blog-deployer"
  display_name = "Deploys blog.lawrencejones.dev from GitHub Actions"
}

# Workload Identity Federation: GitHub's OIDC token is exchanged for short-lived Google
# credentials, so no key exists to leak.
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.required]
}

locals {
  # Numeric IDs rather than names, so a renamed or re-created repository can't inherit
  # the trust. lawrencejones/blog.lawrencejones.dev, owned by lawrencejones.
  blog_repository_id = "171137208"
  blog_owner_id      = "3518874"
}

resource "google_iam_workload_identity_pool_provider" "blog" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "blog-lawrencejones-dev"
  display_name                       = "blog.lawrencejones.dev"

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
  }

  # Only master of this repository may authenticate at all.
  attribute_condition = join(" && ", [
    "assertion.repository_id == '${local.blog_repository_id}'",
    "assertion.repository_owner_id == '${local.blog_owner_id}'",
    "assertion.ref == 'refs/heads/master'",
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "blog_deployer_github" {
  service_account_id = google_service_account.blog_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_id/${local.blog_repository_id}"
}

output "github_actions_variables" {
  description = "Set these as repository variables on lawrencejones/blog.lawrencejones.dev."
  value = {
    GCP_WORKLOAD_IDENTITY_PROVIDER = google_iam_workload_identity_pool_provider.blog.name
    GCP_SERVICE_ACCOUNT            = google_service_account.blog_deployer.email
  }
}
