################################################################################
# lawrencejones.dev: Cloudflare zone
################################################################################
#
# DNS and page rules for lawrencejones.dev. Rewritten in 2026-10 for the current
# Cloudflare provider; the previous config targeted provider 2.1 and its state was
# abandoned rather than migrated through three breaking major versions.
#
# Authenticate with a scoped API token (Zone:Read, DNS:Edit, Page Rules:Edit on this
# zone), kept outside the repository:
#
#   export CLOUDFLARE_API_TOKEN=$(cat ~/.config/cloudflare/token)
#
# State lives alongside the GCP project's, so authenticate to Google as well (see the
# repository README).

terraform {
  required_version = ">= 1.5"

  backend "gcs" {
    bucket = "lawrjone-tfstate"
    prefix = "lawrencejones.dev"
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.0"
    }
  }
}

provider "cloudflare" {}

locals {
  zone_id = "3c87c1e12539fa0eb8abdf2152c20cc3" # lawrencejones.dev
}

################################################################################
# Sites
################################################################################

# The blog: a GCS bucket served through Cloudflare (bucket in projects/lawrjone).
resource "cloudflare_dns_record" "blog" {
  zone_id = local.zone_id
  name    = "blog.lawrencejones.dev"
  type    = "CNAME"
  content = "c.storage.googleapis.com"
  proxied = true
  ttl     = 1 # automatic, required for proxied records
}

# The apex has no site of its own. It needs a proxied record for the page rule below to
# take effect, which then redirects everything to the blog.
resource "cloudflare_dns_record" "root" {
  zone_id = local.zone_id
  name    = "lawrencejones.dev"
  type    = "CNAME"
  content = "c.storage.googleapis.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "www" {
  zone_id = local.zone_id
  name    = "www.lawrencejones.dev"
  type    = "CNAME"
  content = "lawrencejones.dev"
  proxied = true
  ttl     = 1
}

resource "cloudflare_page_rule" "root_to_blog" {
  zone_id  = local.zone_id
  target   = "lawrencejones.dev/*"
  priority = 2
  status   = "active"

  actions = {
    forwarding_url = {
      url         = "https://blog.lawrencejones.dev/"
      status_code = 302
    }
  }
}

resource "cloudflare_page_rule" "https" {
  zone_id  = local.zone_id
  target   = "http://*lawrencejones.dev/*"
  priority = 1
  status   = "active"

  actions = {
    always_use_https         = true
    automatic_https_rewrites = "on"
  }
}

# Status page for an incident.io staging demo.
resource "cloudflare_dns_record" "super_payments" {
  zone_id = local.zone_id
  name    = "super-payments.lawrencejones.dev"
  type    = "CNAME"
  content = "statuspage.staging.incident.io"
  proxied = false
  ttl     = 1
}

################################################################################
# Email: Google Workspace
################################################################################

# MX records as per https://support.google.com/a/answer/174125
locals {
  google_mx = {
    primary = { host = "aspmx.l.google.com", priority = 1 }
    alt1    = { host = "alt1.aspmx.l.google.com", priority = 5 }
    alt2    = { host = "alt2.aspmx.l.google.com", priority = 5 }
    alt3    = { host = "alt3.aspmx.l.google.com", priority = 10 }
    alt4    = { host = "alt4.aspmx.l.google.com", priority = 10 }
  }
}

resource "cloudflare_dns_record" "google_mx" {
  for_each = local.google_mx

  zone_id  = local.zone_id
  name     = "lawrencejones.dev"
  type     = "MX"
  content  = each.value.host
  priority = each.value.priority
  ttl      = 1
}

# SPF: only Google Workspace may send as lawrencejones.dev. Softfail (~all) rather than
# fail (-all) so mail from a sender not listed here is marked rather than rejected.
resource "cloudflare_dns_record" "spf" {
  zone_id = local.zone_id
  name    = "lawrencejones.dev"
  type    = "TXT"
  content = "v=spf1 include:_spf.google.com ~all"
  ttl     = 1
}

# DMARC in monitoring mode: receivers deliver as normal but send daily aggregate reports
# of who is sending as this domain. Once the reports show only legitimate senders,
# tighten to p=quarantine and then p=reject.
resource "cloudflare_dns_record" "dmarc" {
  zone_id = local.zone_id
  name    = "_dmarc.lawrencejones.dev"
  type    = "TXT"
  content = "v=DMARC1; p=none; rua=mailto:me@lawrencejones.dev"
  ttl     = 1
}

################################################################################
# Verification
################################################################################

resource "cloudflare_dns_record" "google_workspace_verification" {
  zone_id = local.zone_id
  name    = "lawrencejones.dev"
  type    = "TXT"
  content = "google-site-verification=ReFuUluZo2ZlqwMaFZWS6peVkwVbZ-IjDZPnOODmHYI"
  ttl     = 1
}

resource "cloudflare_dns_record" "google_search_verification" {
  zone_id = local.zone_id
  name    = "lawrencejones.dev"
  type    = "TXT"
  content = "google-site-verification=p7DAPlFYAWHO66nFY6lKButoMehTQF58j-SFD0F13pM"
  ttl     = 1
}

# Bluesky handle: @lawrencejones.dev
resource "cloudflare_dns_record" "atproto" {
  zone_id = local.zone_id
  name    = "_atproto.lawrencejones.dev"
  type    = "TXT"
  content = "did=did:plc:ggudiwnsnihgu2f7vbpxrwmz"
  ttl     = 1
}
