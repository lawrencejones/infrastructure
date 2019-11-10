################################################################################
# Backend
################################################################################

terraform {
  backend "gcs" {
    bucket = "lawrjone-tfstate"
    prefix = "projects/vault"
  }
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
