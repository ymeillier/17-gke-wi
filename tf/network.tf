# VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = google_project.project.project_id
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  
  depends_on = [google_project_service.services]
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  project       = google_project.project.project_id
  network       = google_compute_network.vpc.self_link
  region        = var.subnet_region
  ip_cidr_range = var.subnet_range

  secondary_ip_range {
    range_name    = var.pod_range_name
    ip_cidr_range = var.pod_range
  }

  secondary_ip_range {
    range_name    = var.svc_range_name
    ip_cidr_range = var.svc_range
  }
}

# Firewall Rules

# Allow internal traffic within the VPC
resource "google_compute_firewall" "allow_internal" {
  name        = "${var.vpc_name}-allow-internal"
  project     = google_project.project.project_id
  network     = google_compute_network.vpc.name
  description = "Allow internal traffic from subnet"

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_range]
}

# Allow SSH from IAP
resource "google_compute_firewall" "allow_ssh_iap" {
  name        = "${var.vpc_name}-allow-ssh-iap"
  project     = google_project.project.project_id
  network     = google_compute_network.vpc.name
  description = "Allow SSH from IAP"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

# Allow ICMP from anywhere (Optional, matching script)
resource "google_compute_firewall" "allow_icmp" {
  name        = "${var.vpc_name}-allow-icmp"
  project     = google_project.project.project_id
  network     = google_compute_network.vpc.name
  description = "Allow ICMP from anywhere"

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}
