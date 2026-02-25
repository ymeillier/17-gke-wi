# Project IAM Roles
resource "google_project_iam_member" "project_owner" {
  project = google_project.project.project_id
  role    = "roles/owner"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "iam_security_admin" {
  project = google_project.project.project_id
  role    = "roles/iam.securityAdmin"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "iam_sa_admin" {
  project = google_project.project.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "iam_sa_key_admin" {
  project = google_project.project.project_id
  role    = "roles/iam.serviceAccountKeyAdmin"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "iam_sa_token_creator" {
  project = google_project.project.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "logging_admin" {
  project = google_project.project.project_id
  role    = "roles/logging.admin"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "monitoring_admin" {
  project = google_project.project.project_id
  role    = "roles/monitoring.admin"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "monitoring_dashboard_editor" {
  project = google_project.project.project_id
  role    = "roles/monitoring.dashboardEditor"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "service_usage_admin" {
  project = google_project.project.project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "storage_admin" {
  project = google_project.project.project_id
  role    = "roles/storage.admin"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "compute_viewer" {
  project = google_project.project.project_id
  role    = "roles/compute.viewer"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "container_admin" {
  project = google_project.project.project_id
  role    = "roles/container.admin"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "gkehub_admin" {
  project = google_project.project.project_id
  role    = "roles/gkehub.admin"
  member  = "user:${local.user_account}"
  depends_on = [google_project_service.services]
}

# Argolis Policy Fixes
# Note: google_org_policy_policy requires orgpolicy.googleapis.com to be enabled
# We are waiting for services to be enabled via explicit depends_on if needed, 
# but Terraform usually handles dependencies. However, org policies can be tricky.

resource "google_project_organization_policy" "restore_default" {
  for_each = toset([
    "compute.trustedImageProjects",
    "compute.vmExternalIpAccess",
    "compute.restrictSharedVpcSubnetworks",
    "compute.restrictSharedVpcHostProjects",
    "compute.restrictVpcPeering",
    "compute.restrictVpnPeerIPs",
    "compute.vmCanIpForward",
    "essentialcontacts.allowedContactDomains",
    "iam.allowedPolicyMemberDomains",
    "compute.requireShieldedVm",
    "compute.requireOsLogin",
    "iam.disableServiceAccountKeyCreation",
    "iam.disableServiceAccountCreation",
    "compute.skipDefaultNetworkCreation",
    "compute.disableVpcExternalIpv6",
    "compute.disableSerialPortAccess"
  ])

  project    = google_project.project.project_id
  constraint = each.key

  restore_policy {
    default = true
  }

  depends_on = [google_project_service.services]
}
