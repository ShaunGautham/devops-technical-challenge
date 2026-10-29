
terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  # CI supplies the pre-created, versioned GCS state bucket at init time.
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 8.0"
    }
  }
}
