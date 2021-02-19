resource "google_service_account" "pinger" {
  account_id = "pinger"
}

resource "google_service_account_key" "pinger" {
  service_account_id = google_service_account.pinger.id
}

resource "google_pubsub_topic" "pinger_events" {
  name = "pinger-events"
}

module "pinger_events_publisher" {
  source = "../../modules/pubsub_topic_publisher"

  project    = google_project.default.id
  topic_name = google_pubsub_topic.pinger_events.name
  publishers = [
    "serviceAccount:${google_service_account.pinger.email}",
  ]
}

module "pinger_events_pinger" {
  source = "../../modules/pubsub_subscription"

  subscription_suffix = "pinger"
  topic_name          = google_pubsub_topic.pinger_events.name
  project             = google_project.default.id
  consumers = [
    "serviceAccount:${google_service_account.pinger.email}",
  ]
}
