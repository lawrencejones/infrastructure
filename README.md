# Infrastructure

Terraform for my personal infrastructure.

```
projects
├── lawrjone            # GCP project: blog bucket and deploy identity, storage, DNS zone
└── lawrencejones.dev   # Cloudflare: lawrencejones.dev DNS and page rules
```

State for every project lives in the `lawrjone-tfstate` bucket, versioned and private.

## Running Terraform

Authenticate as yourself; there are no service account keys.

```shell
gcloud auth application-default login
cd projects/lawrjone
terraform init
terraform plan
```

If application default credentials aren't set up, pass a short-lived token instead:

```shell
GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token) terraform plan
```

## blog.lawrencejones.dev

The blog is a static site in a GCS bucket served through Cloudflare. GitHub Actions in
[lawrencejones/blog.lawrencejones.dev](https://github.com/lawrencejones/blog.lawrencejones.dev)
deploys it, authenticating with Workload Identity Federation: the `github` pool only
trusts that repository's master branch, so no deploy key exists to leak. The bucket can
be read by anyone but not listed.
