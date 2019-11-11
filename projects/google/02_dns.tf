################################################################################
# DNS
################################################################################

resource "google_dns_managed_zone" "lawrjone" {
  name        = "lawrjone"
  dns_name    = "lawrjone.xyz."
  description = "Non-public facing websites"
}

################################################################################
# Service accounts
################################################################################

############################################################
# external-dns
############################################################

resource "google_service_account" "external_dns" {
  account_id = "external-dns"
}

data "google_iam_policy" "external_dns_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"
    members = [
      "serviceAccount:${var.default_project}.svc.id.goog[external-dns/external-dns]",
    ]
  }
}

resource "google_service_account_iam_policy" "external_dns_identity" {
  service_account_id = google_service_account.external_dns.name
  policy_data        = data.google_iam_policy.external_dns_identity.policy_data
}

resource "google_project_iam_member" "external_dns_dns_admin" {
  role   = "roles/dns.admin"
  member = "serviceAccount:${google_service_account.external_dns.email}"
}

############################################################
# cert-manager
############################################################

resource "google_service_account" "cert_manager" {
  account_id = "cert-manager"
}

data "google_iam_policy" "cert_manager_identity" {
  binding {
    role = "roles/iam.workloadIdentityUser"
    members = [
      "serviceAccount:${var.default_project}.svc.id.goog[cert-manager/cert-manager]",
    ]
  }
}

resource "google_service_account_iam_policy" "cert_manager_identity" {
  service_account_id = google_service_account.cert_manager.name
  policy_data        = data.google_iam_policy.cert_manager_identity.policy_data
}

resource "google_project_iam_member" "cert_manager_dns_admin" {
  role   = "roles/dns.admin"
  member = "serviceAccount:${google_service_account.cert_manager.email}"
}

################################################################################
# GSuite
################################################################################

resource "google_dns_record_set" "gsuite_verification" {
  managed_zone = google_dns_managed_zone.lawrjone.name
  name         = google_dns_managed_zone.lawrjone.dns_name
  rrdatas      = ["google-site-verification=mr-VbSc9nKUdFa-Pe4xl0AedX3hCAI_DbYhJ_P_my8E"]
  type         = "TXT"
  ttl          = 300
}

# GSuite MX record setup. Several levels of priority, configured as per Google's
# guidelines in https://support.google.com/a/answer/174125?hl=en
resource "google_dns_record_set" "gsuite_mx_google" {
  managed_zone = google_dns_managed_zone.lawrjone.name
  name         = google_dns_managed_zone.lawrjone.dns_name
  type         = "MX"
  ttl          = 3600

  rrdatas = [
    "1 aspmx.l.google.com.",
    "5 alt1.aspmx.l.google.com.",
    "5 alt2.aspmx.l.google.com.",
    "10 alt3.aspmx.l.google.com.",
    "10 alt4.aspmx.l.google.com."
  ]
}
