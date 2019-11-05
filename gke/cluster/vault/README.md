# vault

Boots Vault as a secret management service, using GCS as a backend. The pods use
workload identity to bind to a GCP service account which has access to the KMS
master key, permitting auto-unseal of Vault when it firsts boots up.

The unseal process places an encrypted root token into the GCS bucket. You can
access that token by using gcloud to decrypt the contents, using the key that is
located in KMS. This key can be exported as the `VAULT_TOKEN` environment
variable and used to configure administrative parts of Vault, like enabling
other authentication plugins.

## Enabling OIDC (SSO via Google)

This process will turn on Google sign-in for any Google email address.

- Deploy using kustomize (`kubectl apply -k .`)
- Create OAuth credentials [here](https://console.cloud.google.com/apis/credentials?authuser=1&folder)
  - Authorised redirect should be https://vault.lawrjone.xyz/ui/vault/auth/oidc/oidc/callback
  - Optionally add http://localhost:8250/oidc/callback as a redirect URL to
    permit authenticating locally using the vault client
  - Capture OAuth client ID and secret
- Capture the root token, so that we're able to configure Vault
  - Pull the token from GCS and decrypt it with gcloud:
    ```console
    $ gsutil cat gs://lawrjone-vault/root-token.enc \
        | base64 -D \
        | gcloud kms decrypt \
            --project lawrjone \
            --location global \
            --keyring vault \
            --key vault-init \
            --ciphertext-file=- \
            --plaintext-file=-
    ```
- Exec into vault pod and run:
  - Authenticate:
    ```console
    $ export VAULT_SKIP_VERIFY=true VAULT_TOKEN=<value-from-before>
    ```
  - Enable and configure the oidc plugin:
    ```console
    # This enables the oidc plugin, required before we can configure
    $ vault auth enable oidc
    Success! Enabled oidc auth method at: oidc/

    # Configure the OAuth parameters, and the default role that will be assigned
    # to users that successfully auth with this plugin
    $ vault write auth/oidc/config \
        oidc_discovery_url="https://accounts.google.com" \
        oidc_client_id="$GOOGLE_API_CLIENT_ID" \
        oidc_client_secret="$GOOGLE_API_CLIENT_SECRET" \
        default_role="google"
    Success! Data written to: auth/oidc/config

    # Let it be the email key of the successful authorisation challenge that we
    # use a 'user claim'. This means we'll map users to their Google email,
    # which will be easier than sub (unique user ID). The email field is only
    # present when the oauth scopes include email.
    #
    # The 'hd' field is the domain of the authorised email. By providing a list,
    # you are saying anyone with emails matching those domains may authorise for
    # this role.
    #
    # The default role is pretty useless, so you'll want to configure something
    # else for that.
    $ vault write -force auth/oidc/role/google -<<EOF
    {
      "user_claim": "email",
      "bound_audiences": "$GOOGLE_API_CLIENT_ID",
      "bound_claims": {
        "hd": ["gocardless.com", "lawrencejones.dev", "lawrjone.xyz"]
      },
      "allowed_redirect_uris": [
        "https://vault.lawrjone.xyz/ui/vault/auth/oidc/oidc/callback",
        "http://localhost:8250/oidc/callback"
      ],
      "role_type": "oidc",
      "oidc_scopes": "openid,email",
      "policies": "default",
      "ttl": "1h"
    }
    EOF
    ```
  - You should now be able to login with any permitted email address via Google
    auth login by going to https://vault.lawrjone.xyz
  - You can also login using `vault login -method=oidc role=google` provided
    either `VAULT_ADDR` is set to `https://vault.lawrjone.xyz` or the `-addr`
    field is provided
