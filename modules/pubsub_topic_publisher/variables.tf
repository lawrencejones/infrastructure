variable "project" {
  type        = "string"
  description = "Project ID which contains topic"
}

variable "topic_name" {
  type        = "string"
  description = "Name of the pubsub topic"
}

variable "publishers" {
  default     = []
  description = "List of identities granted permission to publish to the topic"
}
