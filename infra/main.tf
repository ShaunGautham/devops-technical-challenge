
resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-${var.environment}-vpc"
  auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "subnet" {
  name          = "${var.name_prefix}-${var.environment}-subnet"
  ip_cidr_range = "10.10.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.21.0.0/20"
  }
}


resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = "hello-world-${var.environment}"
  description   = "Docker images for the Hello World Next.js application"
  format        = "DOCKER"
}


resource "google_storage_bucket" "logs" {
  name                        = "${var.project_id}-${var.environment}-logs"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 90
    }
  }
}


resource "google_logging_project_sink" "logs_to_gcs" {
  name        = "${var.name_prefix}-${var.environment}-logs-to-gcs"
  destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"

  filter = "resource.type = \"k8s_container\""

  unique_writer_identity = true
}


resource "google_storage_bucket_iam_member" "logging_writer" {
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.logs_to_gcs.writer_identity
}


resource "google_container_cluster" "primary" {
  name     = "${var.name_prefix}-${var.environment}-gke"
  location = var.region

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  # Create a separate node pool instead of keeping the default one.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Allows Terraform to delete the cluster if needed.
  deletion_protection = false

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_service_account" "gke_nodes" {
  # Include the environment and keep this immutable ID below 30 characters.
  account_id   = "gke-nodes-${var.environment}"
  display_name = "GKE node pool service account"
}

resource "google_project_iam_member" "gke_nodes_default_role" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_artifact_registry_repository_iam_member" "gke_nodes_artifact_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_nodes.email}"
}


resource "google_container_node_pool" "primary" {
  name     = "${var.name_prefix}-${var.environment}-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  depends_on = [
    google_project_iam_member.gke_nodes_default_role,
    google_project_iam_member.gke_nodes_artifact_reader,
  ]

  autoscaling {
    # These limits are totals across the regional node pool, not per zone.
    total_min_node_count = 1
    total_max_node_count = 2
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = 30
    disk_type       = "pd-standard"
    service_account = google_service_account.gke_nodes.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      environment = var.environment
    }
  }
}
