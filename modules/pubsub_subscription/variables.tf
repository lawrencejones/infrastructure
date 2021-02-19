variable "project" {
  type        = "string"
  description = "Project ID which contains topic"
}

variable "enabled" {
  description = "Whether the subscription is enabled, normally used to account for environment differences"
  default     = 1
}

variable "topic_name" {
  type        = "string"
  description = "Name of the pubsub topic"
}

variable "subscription_suffix" {
  type        = "string"
  description = "Used to generate the subscription name: topic.suffix"
}

variable "consumers" {
  default     = []
  description = "List of identities granted permission to consume this subscription"
}

################################################################################
# Pass-through to pubsub_subscription resource
################################################################################

variable "labels" {
  default = {}
}

variable "message_retention_duration" {
  default = "604800s"
}

variable "retain_acked_messages" {
  default = false
}

variable "ack_deadline_seconds" {
  default = 10
}
