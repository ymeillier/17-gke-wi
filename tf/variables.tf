variable "folder_parent" {
  description = "Parent for the new folder (e.g., organizations/123456789 or folders/123456789)"
  type        = string
  default     = "folders/199746281786"
}

variable "billing_account" {
  description = "Billing Account ID to link the project to (optional if ../.config_billing_id exists)"
  type        = string
  default     = null
}

variable "project_name_prefix" {
  description = "Prefix for the project name"
  type        = string
  default     = "gke-lab"
}

variable "folder_name_suffix" {
  description = "Suffix for the folder name (if null, defaults to parent directory name)"
  type        = string
  default     = null
}

variable "user_account" {
  description = "The user account to perform operations as and assign permissions to (optional if ../gcloud/.config_account exists)"
  type        = string
  default     = "admin@meillier.altostrat.com"
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "vpc-main"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "subnet-main"
}

variable "subnet_region" {
  description = "Region for the subnet"
  type        = string
  default     = "us-central1"
}

variable "subnet_range" {
  description = "IP range for the subnet"
  type        = string
  default     = "10.128.0.0/20"
}

variable "pod_range" {
  description = "IP range for pods"
  type        = string
  default     = "192.168.0.0/18"
}

variable "pod_range_name" {
  description = "Name of the secondary range for pods"
  type        = string
  default     = "pods"
}

variable "svc_range" {
  description = "IP range for services"
  type        = string
  default     = "172.16.0.0/28"
}

variable "svc_range_name" {
  description = "Name of the secondary range for services"
  type        = string
  default     = "services"
}

variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "gke-cluster-01"
}

variable "gke_release_channel" {
  description = "Release channel for GKE (regular, rapid, stable)"
  type        = string
  default     = "regular"
}

variable "gke_version" {
  description = "Version of GKE cluster"
  type        = string
  default     = "1.33.5-gke.2019000"
}

variable "gke_num_nodes" {
  description = "Number of nodes per zone"
  type        = number
  default     = 1
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "gke_nodes_zones" {
  description = "List of zones for the node pool"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}
