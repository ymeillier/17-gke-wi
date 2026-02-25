output "project_id" {
  description = "The ID of the created project"
  value       = google_project.project.project_id
}

output "folder_id" {
  description = "The ID of the created folder"
  value       = google_folder.folder.name
}

output "vpc_name" {
  description = "The name of the VPC"
  value       = google_compute_network.vpc.name
}

output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "gke_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "gke_region" {
  description = "The region of the GKE cluster"
  value       = var.subnet_region
}

output "gke_console_url" {
  description = "The console URL of the GKE cluster"
  value       = "https://console.cloud.google.com/kubernetes/list/overview?project=${google_project.project.project_id}"
}
