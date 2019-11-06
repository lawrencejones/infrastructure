################################################################################
# Backend
################################################################################

terraform {
  backend "gcs" {
    bucket = "lawrjone-tfstate"
    prefix = "projects/google/vault/config"
  }
}

################################################################################
# Provider
################################################################################

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

################################################################################
# Google authentication
################################################################################

locals {
  oauth_client_id     = "206046083972-d14bgi6fep0tcjbp4ea5tp43rlbt5vg7.apps.googleusercontent.com"
  oauth_client_secret = "Cq_d8aZa_wkngUI2NxIXbnAS"
}

resource "vault_jwt_auth_backend" "oidc" {
  type = "oidc"

  path         = "oidc"
  description  = "Google login"
  default_role = "default"

  oidc_discovery_url = "https://accounts.google.com"
  oidc_client_id     = local.oauth_client_id
  oidc_client_secret = local.oauth_client_secret

  lifecycle {
    ignore_changes = [oidc_client_secret]
  }
}

resource "vault_jwt_auth_backend_role" "oidc" {
  backend   = vault_jwt_auth_backend.oidc.path
  role_name = "default"

  token_policies = ["developer"]

  user_claim      = "email"
  bound_audiences = [local.oauth_client_id]
  bound_claims = {
    hd = "gocardless.com,lawrencejones.dev,lawrjone.xyz"
  }

  token_ttl   = 86400 # 1d
  role_type   = "oidc"
  oidc_scopes = ["openid", "email"]
  allowed_redirect_uris = [
    "https://vault.lawrjone.xyz/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]
}

################################################################################
# Kubernetes authentication
################################################################################

resource "vault_auth_backend" "kubernetes_primary" {
  type = "kubernetes"
  path = "kubernetes.primary"
}

data "google_container_cluster" "primary" {
  name     = "primary"
  location = var.region
}

resource "vault_kubernetes_auth_backend_config" "primary" {
  backend            = vault_auth_backend.kubernetes_primary.path
  kubernetes_host    = "https://${data.google_container_cluster.primary.endpoint}"
  kubernetes_ca_cert = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

resource "vault_kubernetes_auth_backend_role" "primary" {
  backend   = vault_auth_backend.kubernetes_primary.path
  role_name = "default"
  token_ttl = 3600 # 300 # 5m
  token_policies = [
    vault_policy.kubernetes_primary_reader.name,
  ]

  # https://github.com/hashicorp/vault-plugin-auth-kubernetes/pull/66
  bound_service_account_names      = split(",", "a*,b*,c*,d*,e*,f*,h*,i*,j*,k*,l*,m*,n*,o*,p*,q*,r*,s*,t*,u*,v*,w*,x*,y*,z*,1*,2*,3*,4*,5*,6*,7*,8*,9*,0*")
  bound_service_account_namespaces = ["*"]
}

################################################################################
# Policies
################################################################################

resource "vault_policy" "developer" {
  name   = "developer"
  policy = data.vault_policy_document.developer.hcl
}

data "vault_policy_document" "developer" {
  # Allow users to see all mounted secret engines
  rule {
    path         = "sys/mounts"
    capabilities = ["read", "list"]
  }

  # Developers should be able to create new secrets, and view what exists
  rule {
    path         = "secret/*"
    capabilities = ["list", "create"]
  }
}

# One policy per Kubernetes cluster
resource "vault_policy" "kubernetes_primary_reader" {
  name   = "kubernetes-primary-reader"
  policy = data.vault_policy_document.kubernetes_primary_reader.hcl
}

locals {
  kubernetes_primary_reader_template = join(
    "/", [
      "secret/%s/kubernetes",
      "primary",
      "{{identity.entity.aliases.${vault_auth_backend.kubernetes_primary.accessor}.metadata.service_account_namespace}}",
      "{{identity.entity.aliases.${vault_auth_backend.kubernetes_primary.accessor}.metadata.service_account_name}}",
      "*",
    ],
  )
}

data "vault_policy_document" "kubernetes_primary_reader" {
  rule {
    path         = format(local.kubernetes_primary_reader_template, "data")
    capabilities = ["read"]
  }

  rule {
    path         = format(local.kubernetes_primary_reader_template, "metadata")
    capabilities = ["list"]
  }
}

################################################################################
# Engines
################################################################################

resource "vault_mount" "secret" {
  path        = "secret"
  type        = "kv"
  description = "Generic secrets store, including environment variables"

  # Version 2 is the latest:
  # https://www.vaultproject.io/docs/secrets/kv/index.html
  options = {
    version = "2"
  }
}
