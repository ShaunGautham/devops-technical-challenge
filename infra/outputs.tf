
output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_cidr" {
  description = "IP address range of the subnet"
  value       = google_compute_subnetwork.subnet.ip_cidr_range
}


output "artifact_registry_repository" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.docker.repository_id
}

output "artifact_registry_url" {
  description = "Artifact Registry Docker repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}


output "logs_bucket_name" {
  description = "Cloud Storage bucket for exported Kubernetes logs"
  value       = google_storage_bucket.logs.name
}


output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "gke_cluster_location" {
  description = "Region where the GKE cluster is created"
  value       = google_container_cluster.primary.location
}

output "gke_node_pool_name" {
  description = "Name of the GKE node pool"
  value       = google_container_node_pool.primary.name
}
