################################################################################
# Backend
################################################################################

terraform {
  backend "gcs" {
    bucket  = "lawrjone-tfstate"
    prefix  = "terraform/state/lawrencejones.dev"
    project = "lawrjone"
  }
}

################################################################################
# Provider
################################################################################

provider "cloudflare" {
  version = "1.10"
}

################################################################################
# GSuite
################################################################################

resource "cloudflare_record" "gsuite_verification" {
  domain = "lawrencejones.dev"
  name   = "@"
  value  = "google-site-verification=ReFuUluZo2ZlqwMaFZWS6peVkwVbZ-IjDZPnOODmHYI"
  type   = "TXT"
}

# search.google.com domain ownership proof
resource "cloudflare_record" "google_search_ownership" {
  domain = "lawrencejones.dev"
  name   = "@"
  value  = "google-site-verification=p7DAPlFYAWHO66nFY6lKButoMehTQF58j-SFD0F13pM"
  type   = "TXT"
}

# GSuite MX record setup. Several levels of priority, configured as per Google's
# guidelines in https://support.google.com/a/answer/174125?hl=en
resource "cloudflare_record" "gsuite_mx_google_primary" {
  domain   = "lawrencejones.dev"
  name     = "lawrencejones.dev"
  value    = "aspmx.l.google.com"
  type     = "MX"
  priority = "1"
}

resource "cloudflare_record" "gsuite_mx_google_alt_1" {
  domain   = "lawrencejones.dev"
  name     = "lawrencejones.dev"
  value    = "alt1.aspmx.l.google.com"
  type     = "MX"
  priority = "5"
}

resource "cloudflare_record" "gsuite_mx_google_alt_2" {
  domain   = "lawrencejones.dev"
  name     = "lawrencejones.dev"
  value    = "alt2.aspmx.l.google.com"
  type     = "MX"
  priority = "5"
}

resource "cloudflare_record" "gsuite_mx_google_alt_3" {
  domain   = "lawrencejones.dev"
  name     = "lawrencejones.dev"
  value    = "alt3.aspmx.l.google.com"
  type     = "MX"
  priority = "10"
}

resource "cloudflare_record" "gsuite_mx_google_alt_4" {
  domain   = "lawrencejones.dev"
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
  zone     = "lawrencejones.dev"
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
  domain  = "lawrencejones.dev"
  name    = "@"
  value   = "c.storage.googleapis.com"
  type    = "CNAME"
  proxied = true
}

# www.lawrencejones.dev -> lawrencejones.dev
resource "cloudflare_record" "www" {
  domain  = "lawrencejones.dev"
  name    = "www"
  value   = "lawrencejones.dev"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_page_rule" "root_to_blog" {
  target   = "lawrencejones.dev/*"
  zone     = "lawrencejones.dev"
  priority = 2

  actions {
    forwarding_url = [{
      url         = "https://blog.lawrencejones.dev/"
      status_code = 302
    }]
  }
}

resource "cloudflare_record" "blog" {
  domain  = "lawrencejones.dev"
  name    = "blog"
  value   = "c.storage.googleapis.com"
  type    = "CNAME"
  proxied = true
}
