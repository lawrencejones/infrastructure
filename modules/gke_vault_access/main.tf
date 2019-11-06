# Authenticate against Vault by fetching the root token from GCS and decrypting
# it every time we boot terraform. This means we need a Google login that has
# permission to access the key in GCS, and decrypt it using KMS. As this is my
# personal project, I'm running as me@lawrjone.xyz which is a superuser. For a
# corporate deployment, this would be the terraform administrator.
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
