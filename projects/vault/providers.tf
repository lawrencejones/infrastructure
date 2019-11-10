################################################################################
# Provider
################################################################################

provider "google" {
  region  = var.region
  version = "2.18.1"
  project = var.default_project
}

provider "vault" {
  address = "https://vault.lawrjone.xyz"
  token   = data.google_kms_secret.vault_token.plaintext
}

provider "http" {
}

data "google_storage_object_signed_url" "root_token_enc_url" {
  bucket   = "lawrjone-vault"
  path     = "root-token.enc"
  duration = "1m"
}

data "http" "root_token_enc" {
  url = data.google_storage_object_signed_url.root_token_enc_url.signed_url
}

data "google_kms_secret" "vault_token" {
  crypto_key = "projects/lawrjone/locations/global/keyRings/vault/cryptoKeys/vault-init"
  ciphertext = data.http.root_token_enc.body
}
