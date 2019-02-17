################################################################################
# Backend
################################################################################

terraform {
  backend "gcs" {
    bucket  = "lawrjone-tfstate"
    prefix  = "terraform/state/lawrjone.xyz"
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
  domain = "lawrjone.xyz"
  name   = "@"
  value  = "google-site-verification=mr-VbSc9nKUdFa-Pe4xl0AedX3hCAI_DbYhJ_P_my8E"
  type   = "TXT"
}

# GSuite MX record setup. Several levels of priority, configured as per Google's
# guidelines in https://support.google.com/a/answer/174125?hl=en
resource "cloudflare_record" "gsuite_mx_google_primary" {
  domain   = "lawrjone.xyz"
  name     = "lawrjone.xyz"
  value    = "aspmx.l.google.com"
  type     = "MX"
  priority = "1"
}

resource "cloudflare_record" "gsuite_mx_google_alt_1" {
  domain   = "lawrjone.xyz"
  name     = "lawrjone.xyz"
  value    = "alt1.aspmx.l.google.com"
  type     = "MX"
  priority = "5"
}

resource "cloudflare_record" "gsuite_mx_google_alt_2" {
  domain   = "lawrjone.xyz"
  name     = "lawrjone.xyz"
  value    = "alt2.aspmx.l.google.com"
  type     = "MX"
  priority = "5"
}

resource "cloudflare_record" "gsuite_mx_google_alt_3" {
  domain   = "lawrjone.xyz"
  name     = "lawrjone.xyz"
  value    = "alt3.aspmx.l.google.com"
  type     = "MX"
  priority = "10"
}

resource "cloudflare_record" "gsuite_mx_google_alt_4" {
  domain   = "lawrjone.xyz"
  name     = "lawrjone.xyz"
  value    = "alt4.aspmx.l.google.com"
  type     = "MX"
  priority = "10"
}

################################################################################
# Security
################################################################################

resource "cloudflare_page_rule" "https" {
  target = "http://*lawrjone.xyz/*"
  zone   = "lawrjone.xyz"

  actions {
    always_use_https         = true
    automatic_https_rewrites = "on"
  }
}

################################################################################
# Sites
################################################################################

resource "cloudflare_page_rule" "root_to_blog" {
  target = "lawrjone.xyz/*"
  zone   = "lawrjone.xyz"

  actions {
    forwarding_url = [{
      url         = "https://blog.lawrjone.xyz/"
      status_code = 302
    }]
  }
}

resource "cloudflare_record" "blog" {
  domain  = "lawrjone.xyz"
  name    = "blog"
  value   = "c.storage.googleapis.com"
  type    = "CNAME"
  proxied = true
}
