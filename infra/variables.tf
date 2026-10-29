
variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
  default     = "devops"
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

  validation {
    condition     = length(var.environment) <= 10 && can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.environment))
    error_message = "environment must be lowercase, start with a letter, end with a letter or digit, and be at most 10 characters."
  }
}

variable "name_prefix" {
  description = "Prefix used to name infrastructure resources"
  type        = string
  default     = "hello-world"

}

variable "machine_type" {
  description = "Machine type for GKE worker nodes"
  type        = string
  default     = "e2-medium"
}
