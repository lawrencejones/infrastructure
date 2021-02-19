/**
 * # module: `pubsub_topic_publisher`
 *
 * This module grants the given identities permission to publish to the
 * specified topic.
 */

################################################################################
# Pubsub IAMs
################################################################################

resource "google_pubsub_topic_iam_member" "viewer" {
  count = length(var.publishers)

  project = var.project
  topic   = var.topic_name
  role    = "roles/pubsub.viewer"
  member  = element(var.publishers, count.index)
}

resource "google_pubsub_topic_iam_member" "publisher" {
  count = length(var.publishers)

  project = var.project
  topic   = var.topic_name
  role    = "roles/pubsub.publisher"
  member  = element(var.publishers, count.index)
}
