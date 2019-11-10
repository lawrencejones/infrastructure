################################################################################
# Service accounts
################################################################################

resource "google_service_account" "vault_server" {
  account_id = "vault-server"
}

# This policy permits the vault-server service account within the vault
# namespace of the gke cluster in this project to be a workloadIdentityUser. The
# subsequent iam policy binds this ability to the vault-server Google service
# account.
#
# $ gcloud iam service-accounts add-iam-policy-binding \
#     --role roles/iam.workloadIdentityUser \
#     --member "serviceAccount:[PROJECT_ID].svc.id.goog[[K8S_NAMESPACE]/[KSA_NAME]]" \
#     [GSA_NAME]@[PROJECT_ID].iam.gserviceaccount.com
#
data "google_iam_policy" "vault_server_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"
    members = [
      "serviceAccount:${var.default_project}.svc.id.goog[vault/vault-server]",
    ]
  }
}

resource "google_service_account_iam_policy" "vault_identity" {
  service_account_id = google_service_account.vault_server.name
  policy_data        = data.google_iam_policy.vault_server_identity.policy_data
}

################################################################################
# KMS
################################################################################

resource "google_kms_key_ring" "vault" {
  name     = "vault"
  location = "global"
}

resource "google_kms_crypto_key" "vault_init" {
  name     = "vault-init"
  key_ring = google_kms_key_ring.vault.self_link
  purpose  = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

# Use binding as only vault-server should be able to use this key
resource "google_kms_crypto_key_iam_binding" "vault_init" {
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  crypto_key_id = google_kms_crypto_key.vault_init.id
  members = [
    "serviceAccount:${google_service_account.vault_server.email}",
  ]
}

################################################################################
# Storage
################################################################################

resource "google_storage_bucket" "vault" {
  name          = "lawrjone-vault"
  location      = var.region
  storage_class = "REGIONAL"
}

resource "google_storage_bucket_iam_member" "admin" {
  bucket = google_storage_bucket.vault.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.vault_server.email}"
}
