################################################################################
# Variables
################################################################################

variable "vault_address" {
  description = "address of the vault server e.g. https://vault.com"
}

variable "cluster_identifier" {
  description = "logical identifier for this cluster: sets the mount prefix for this clusters secret access"
}

variable "kubernetes_cluster_name" {
  description = "name of the kubernetes cluster to configure for vault access"
}

variable "kubernetes_cluster_location" {
  description = "location of kubernetes cluster to configure vault access"
}

################################################################################
# Providers
################################################################################

############################################################
# Vault
############################################################

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

############################################################
# Kubernetes
############################################################

provider "kubernetes" {
  load_config_file = false

  host  = "https://${data.google_container_cluster.cluster.endpoint}"
  token = data.google_client_config.default.access_token

  cluster_ca_certificate = base64decode(data.google_container_cluster.cluster.master_auth.0.cluster_ca_certificate)
}

data "google_client_config" "default" {}

data "google_container_cluster" "cluster" {
  name     = var.kubernetes_cluster_name
  location = var.kubernetes_cluster_location
}

################################################################################
# Vault auth
################################################################################

resource "vault_auth_backend" "cluster" {
  type = "kubernetes"
  path = "kubernetes.${var.cluster_identifier}"
}

resource "vault_kubernetes_auth_backend_config" "cluster" {
  backend            = vault_auth_backend.cluster.path
  kubernetes_host    = "https://${data.google_container_cluster.cluster.endpoint}"
  kubernetes_ca_cert = base64decode(data.google_container_cluster.cluster.master_auth.0.cluster_ca_certificate)
}

resource "vault_kubernetes_auth_backend_role" "default" {
  backend   = vault_auth_backend.cluster.path
  role_name = "default"
  token_ttl = 3600 # 300 # 5m
  token_policies = [
    vault_policy.cluster_reader.name,
  ]

  # https://github.com/hashicorp/vault-plugin-auth-kubernetes/pull/66
  bound_service_account_names      = formatlist("%s*", split("", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"))
  bound_service_account_namespaces = ["*"]
}

################################################################################
# Vault policy
################################################################################

# One policy per Kubernetes cluster. Permit reading and listing of secrets in
# the namespace constructed from cluster identifier.
resource "vault_policy" "cluster_reader" {
  name   = "kubernetes-reader.${var.cluster_identifier}"
  policy = data.vault_policy_document.cluster_reader.hcl
}

locals {
  cluster_reader_template = join(
    "/", [
      "secret/%s/kubernetes",
      var.cluster_identifier,
      "{{identity.entity.aliases.${vault_auth_backend.cluster.accessor}.metadata.service_account_namespace}}",
      "{{identity.entity.aliases.${vault_auth_backend.cluster.accessor}.metadata.service_account_name}}",
      "*",
    ],
  )
}

data "vault_policy_document" "cluster_reader" {
  rule {
    path         = format(local.cluster_reader_template, "data")
    capabilities = ["read"]
  }

  rule {
    path         = format(local.cluster_reader_template, "metadata")
    capabilities = ["list"]
  }
}

################################################################################
# Kubernetes configuration
################################################################################

resource "kubernetes_namespace" "vault_system" {
  metadata {
    name = "vault-system"
  }
}

# Auth delegator is a role that every service account must have, in order to
# create tokenreviews. This is key to Vault being able to validate the service
# account tokens that kubernetes pods will authenticate with.
resource "kubernetes_cluster_role_binding" "auth_delegator" {
  metadata {
    name = "auth-delegator"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind = "Group"
    name = "system:serviceaccounts"
  }
}

resource "kubernetes_role" "vault_config_viewer" {
  metadata {
    name      = "vault-config-viewer"
    namespace = kubernetes_namespace.vault_system.metadata[0].name
  }
  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = [kubernetes_config_map.vault_config.metadata[0].name]
    verbs          = ["get"]
  }
}

resource "kubernetes_role_binding" "vault_config_viewer_everyone" {
  metadata {
    name      = "vault-config-viewer-everyone"
    namespace = kubernetes_namespace.vault_system.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.vault_config_viewer.metadata[0].name
  }
  subject {
    kind = "Group"
    name = "system:authenticated"
  }
  subject {
    kind = "Group"
    name = "system:serviceaccounts"
  }
}

# This configuration can be used by other tools to help authenticate against
# vault. We provide access to read the configmap to all service accounts.
resource "kubernetes_config_map" "vault_config" {
  metadata {
    name      = "vault-config"
    namespace = kubernetes_namespace.vault_system.metadata[0].name
  }

  data = {
    vault_address     = var.vault_address
    auth_mount_path   = vault_auth_backend.cluster.path
    secret_mount_path = format(local.cluster_reader_template, "data")
  }
}
