# This agent.conf file is provisioned by the gke_vault_access terraform module,
# which has configured this kubernetes cluster with the required access material
# to authenticate against the vault erver.
exit_after_auth = true
pid_file = "/tmp/vault-agent.pid"

vault {
        address = "${vault_address}"
}

auto_auth {
    method "kubernetes" {
        mount_path = "auth/kubernetes.${cluster_project}.${cluster_name}"
        config = {
                role = "default"
        }
    }
    sink "file" {
        config = {
            path = "/tmp/vault-token"
        }
    }
}
