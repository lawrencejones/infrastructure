################################################################################
# Backend
################################################################################

terraform {
  backend "gcs" {
    bucket = "lawrjone-tfstate"
    prefix = "projects/lawrencejones.dev"
  }
}

################################################################################
# Provider
################################################################################

provider "cloudflare" {
  version = "2.1.0"
}

locals {
  zone_id = lookup(data.cloudflare_zones.zone.zones[0], "id")
}

data "cloudflare_zones" "zone" {
  filter {
    name   = "lawrencejones.dev"
    status = "active"
    paused = false
  }
}

################################################################################
# GSuite
################################################################################

resource "cloudflare_record" "gsuite_verification" {
  zone_id = local.zone_id
  name    = "@"
  value   = "google-site-verification=ReFuUluZo2ZlqwMaFZWS6peVkwVbZ-IjDZPnOODmHYI"
  type    = "TXT"
}

# search.google.com zone_id = local.zone_id
resource "cloudflare_record" "google_search_ownership" {
  zone_id = local.zone_id
  name    = "@"
  value   = "google-site-verification=p7DAPlFYAWHO66nFY6lKButoMehTQF58j-SFD0F13pM"
  type    = "TXT"
}

# GSuite MX record setup. Several levels of priority, configured as per Google's
# guidelines in https://support.google.com/a/answer/174125?hl=en
resource "cloudflare_record" "gsuite_mx_google_primary" {
  zone_id  = local.zone_id
  name     = "lawrencejones.dev"
  value    = "aspmx.l.google.com"
  type     = "MX"
  priority = "1"
}

resource "cloudflare_record" "gsuite_mx_google_alt_1" {
  zone_id  = local.zone_id
  name     = "lawrencejones.dev"
  value    = "alt1.aspmx.l.google.com"
  type     = "MX"
  priority = "5"
}

resource "cloudflare_record" "gsuite_mx_google_alt_2" {
  zone_id  = local.zone_id
  name     = "lawrencejones.dev"
  value    = "alt2.aspmx.l.google.com"
  type     = "MX"
  priority = "5"
}

resource "cloudflare_record" "gsuite_mx_google_alt_3" {
  zone_id  = local.zone_id
  name     = "lawrencejones.dev"
  value    = "alt3.aspmx.l.google.com"
  type     = "MX"
  priority = "10"
}

resource "cloudflare_record" "gsuite_mx_google_alt_4" {
  zone_id  = local.zone_id
  name     = "lawrencejones.dev"
  value    = "alt4.aspmx.l.google.com"
  type     = "MX"
  priority = "10"
}

################################################################################
# Security
################################################################################

resource "cloudflare_page_rule" "https" {
  target   = "http://*lawrencejones.dev/*"
  zone_id  = local.zone_id
  priority = 1

  actions {
    always_use_https         = true
    automatic_https_rewrites = "on"
  }
}

################################################################################
# Sites
################################################################################

# Provide a dummy root CNA<E record to enable the page rules to take over, which
# will (for the moment) redirect to the blog.
resource "cloudflare_record" "root" {
  zone_id = local.zone_id
  name    = "@"
  value   = "c.storage.googleapis.com"
  type    = "CNAME"
  proxied = true
}

# www.lawrencejones.dev -> lawrencejones.dev
resource "cloudflare_record" "www" {
  zone_id = local.zone_id
  name    = "www"
  value   = "lawrencejones.dev"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_page_rule" "root_to_blog" {
  target   = "lawrencejones.dev/*"
  zone_id  = local.zone_id
  priority = 2

  actions {
    forwarding_url {
      url         = "https://blog.lawrencejones.dev/"
      status_code = 302
    }
  }
}

resource "cloudflare_record" "blog" {
  zone_id = local.zone_id
  name    = "blog"
  value   = "c.storage.googleapis.com"
  type    = "CNAME"
  proxied = true
}
