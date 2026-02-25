# Dedicated Service Account for GKE Nodes
resource "google_service_account" "gke_node_sa" {
  account_id   = "gke-node-sa"
  display_name = "GKE Node Service Account"
  project      = google_project.project.project_id
  depends_on   = [google_project_service.services]
}

# Assign roles/container.defaultNodeServiceAccount to SA
resource "google_project_iam_member" "gke_node_sa_role" {
  project = google_project.project.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  project  = google_project.project.project_id
  location = var.subnet_region # Regional cluster if region is used, Zonal if zone.
  
  # We want a regional cluster? The script sets GKE_CP_REGION_OR_ZONE = SUBNET_REGION (which is a region us-central1)
  # and GKE_NODES_ZONES = "us-central1-a,us-central1-b,us-central1-c"
  # This implies a Regional Cluster or Zonal with node locations?
  # "The control plane is replicated across three zones in a region ( Creating a zonal clust...)." implies Regional if location is a region.
  
  node_locations = var.gke_nodes_zones

  release_channel {
    channel = var.gke_release_channel == "regular" ? "REGULAR" : (var.gke_release_channel == "rapid" ? "RAPID" : "STABLE")
  }

  min_master_version = var.gke_version
  
  network    = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet.self_link

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pod_range_name
    services_secondary_range_name = var.svc_range_name
  }
  
  # We can't set initial_node_count nicely for regional clusters with autoscaling or specific node pools 
  # but here we use remove_default_node_pool = true to manage node pools separately or just configure it here.
  # The script uses `gcloud container clusters create` which creates a default node pool.
  # To match that behavior closely:
  
  initial_node_count = 1 # This is per zone
  remove_default_node_pool = true  # Best practice is to use a separate node pool resource

  workload_identity_config {
    workload_pool = "${google_project.project.project_id}.svc.id.goog"
  }
  
  # Disable Master Authorized Networks (Script says --no-enable-master-authorized-networks)
  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled = true
  }

  deletion_protection = false # For easier cleanup in labs
  
  depends_on = [
    google_project_service.services,
    google_project_iam_member.gke_node_sa_role
  ]
}

# Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.gke_cluster_name}-node-pool"
  project    = google_project.project.project_id
  location   = var.subnet_region
  cluster    = google_container_cluster.primary.name
  
  node_count = var.gke_num_nodes # Per zone

  node_config {
    machine_type = var.gke_machine_type
    
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_node_sa.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    # enable_ip_alias is implicitly true when ip_allocation_policy is set on cluster
  }
}

# Create a local file with the GKE console URL
resource "local_file" "cluster_url" {
  content  = "https://console.cloud.google.com/kubernetes/list/overview?project=${google_project.project.project_id}"
  filename = "${path.module}/cluster-url.txt"
  depends_on = [google_container_cluster.primary]
}
