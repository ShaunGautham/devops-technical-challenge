
variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "asia-southeast1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "name_prefix" {
  description = "Prefix used to name infrastructure resources"
  type        = string
  default     = "hello-world"
}

variable "node_count" {
  description = "Number of GKE worker nodes"
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be at least 1."
  }
}

variable "machine_type" {
  description = "Machine type for GKE worker nodes"
  type        = string
  default     = "e2-medium"
}
