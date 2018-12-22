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
  value  = "google-site-verification=LkRX9O_g5RERR6kGtMsazedOlIhMrez1c6lQawJK0xU"
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
