terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  alias = "creation"
  # No project/region specified here; we'll provide them in resources or via environment/gcloud
  # or rely on the created project for some resources
}

provider "google" {
  project               = google_project.project.project_id
  billing_project       = google_project.project.project_id
  user_project_override = true
}

resource "random_id" "suffix" {
  byte_length = 2
}

locals {
  # Auto-discovery logic
  # Auto-discovery logic

  # Read from gcloud/.saved_var_file
  saved_var_path    = "${path.module}/../gcloud/.saved_var_file"
  saved_var_content = fileexists(local.saved_var_path) ? file(local.saved_var_path) : ""

  # Extract USER_ACCOUNT
  # export USER_ACCOUNT="admin@meillier.altostrat.com"
  user_account_match     = regexall("export USER_ACCOUNT=\"([^\"]+)\"", local.saved_var_content)
  user_account_from_file = length(local.user_account_match) > 0 ? local.user_account_match[0][0] : null
  user_account           = coalesce(var.user_account, local.user_account_from_file)

  # Extract BILLING_ACCOUNT_ID
  # export BILLING_ACCOUNT_ID="01B10A-601E21-33E959"
  billing_account_match     = regexall("export BILLING_ACCOUNT_ID=\"([^\"]+)\"", local.saved_var_content)
  billing_account_from_file = length(local.billing_account_match) > 0 ? local.billing_account_match[0][0] : null
  billing_account           = coalesce(var.billing_account, local.billing_account_from_file)

  # Logic to determine names from parent directory
  # path.module is ".../tf". Parent is ".../01-test-template-code".
  parent_dir_name = basename(dirname(abspath(path.module)))

  # Dynamic folder name suffix
  # If var is null, use parent dir name.
  folder_name_suffix = var.folder_name_suffix == null ? local.parent_dir_name : var.folder_name_suffix

  # Project Name Prefix
  # If var is default "gke-lab", use "project".
  project_name_prefix = var.project_name_prefix == "gke-lab" ? "project" : var.project_name_prefix
}

# Folder
resource "google_folder" "folder" {
  provider     = google.creation
  display_name = local.folder_name_suffix
  parent       = var.folder_parent
}

# Project
resource "google_project" "project" {
  provider        = google.creation
  name            = "${local.project_name_prefix}-${random_id.suffix.dec}"
  project_id      = "${local.project_name_prefix}-${random_id.suffix.dec}"
  folder_id       = google_folder.folder.name
  billing_account = local.billing_account

  # Skip default network creation
  auto_create_network = false
}

# Enable Services
resource "null_resource" "enable_service_usage_api" {
  provisioner "local-exec" {
    command = "gcloud services enable serviceusage.googleapis.com --project ${google_project.project.project_id}"
  }

  depends_on = [google_project.project]
}

resource "google_project_service" "service_usage" {
  project            = google_project.project.project_id
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
  depends_on         = [null_resource.enable_service_usage_api]
}

resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "orgpolicy.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "gkehub.googleapis.com"
  ])

  project = google_project.project.project_id
  service = each.key

  disable_on_destroy = false
  depends_on         = [google_project_service.service_usage]
}

# Link Billing (Handled by google_project resource, but ensuring we have permissions)
# Note: The user running this must have roles/billing.user on the billing account

# Create execution tracking file in parent directory
resource "local_file" "assets_execution_code" {
  content  = "main.tf"
  filename = "${dirname(abspath(path.module))}/.assets-execution-code"
}

# Configure gcloud for the new project
resource "null_resource" "gcloud_config_setup" {
  provisioner "local-exec" {
    command = <<EOT
      gcloud config set project ${google_project.project.project_id}
      gcloud auth application-default set-quota-project ${google_project.project.project_id}
      gcloud config set billing/quota_project ${google_project.project.project_id}
    EOT
  }

  depends_on = [
    google_project_service.services,
    google_project.project
  ]
}
