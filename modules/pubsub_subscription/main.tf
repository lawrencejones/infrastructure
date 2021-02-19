/**
 * # module: `pubsub_subscription`
 *
 * This module creates a pubsub subscription, configuring the given consumers
 * permissions to subscribe and view. The intent is to provide a working
 * out-the-box experience for consuming from pubsub topics.
 */

################################################################################
# Subscription
################################################################################

resource "google_pubsub_subscription" "subscription" {
  count = var.enabled

  project = var.project
  name    = "${var.topic_name}.${var.subscription_suffix}"
  topic   = var.topic_name

  labels                     = var.labels
  message_retention_duration = var.message_retention_duration
  retain_acked_messages      = var.retain_acked_messages
  ack_deadline_seconds       = var.ack_deadline_seconds
}

################################################################################
# Pubsub IAMs
################################################################################

resource "google_pubsub_subscription_iam_member" "subscriber" {
  count = "${var.enabled * length(var.consumers)}"

  project      = var.project
  subscription = google_pubsub_subscription.subscription[0].path
  role         = "roles/pubsub.subscriber"
  member       = element(var.consumers, count.index)
}

resource "google_pubsub_topic_iam_member" "viewer" {
  count = "${var.enabled * length(var.consumers)}"

  project = var.project
  topic   = var.topic_name
  role    = "roles/pubsub.viewer"
  member  = element(var.consumers, count.index)
}
