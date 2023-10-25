locals {
  service_account_list = compact(
    concat(
      google_service_account.cluster_service_account[*].email,
      ["dummy"],
    ),
  )
  service_account_default_name = "${substr(var.name, 0, min(15, length(var.name)))}-${random_string.cluster_service_account_suffix.result}"

  // if user set var.service_account it will be used even if var.create_service_account==true, so service account will be created but not used
  service_account = (var.service_account == "" || var.service_account == "create") && var.create_service_account ? local.service_account_list[0] : var.service_account

  registry_projects_list = length(var.registry_project_ids) == 0 ? [var.project_id] : var.registry_project_ids
}

resource "random_string" "cluster_service_account_suffix" {
  upper   = false
  lower   = true
  special = false
  length  = 4
}

resource "google_service_account" "cluster_service_account" {
  count        = var.create_service_account ? 1 : 0
  project      = var.project_id
  account_id   = var.service_account_name == "" ? local.service_account_default_name : var.service_account_name
  display_name = "Service account for cluster ${var.name}"
}

resource "google_project_iam_member" "cluster_service_account_log_writer" {
  count   = var.create_service_account ? 1 : 0
  project = google_service_account.cluster_service_account[0].project
  role    = "roles/logging.logWriter"
  member  = google_service_account.cluster_service_account[0].member
}

resource "google_project_iam_member" "cluster_service_account_metric_writer" {
  count   = var.create_service_account ? 1 : 0
  project = google_project_iam_member.cluster_service_account_log_writer[0].project
  role    = "roles/monitoring.metricWriter"
  member  = google_service_account.cluster_service_account[0].member
}

resource "google_project_iam_member" "cluster_service_account_monitoring_viewer" {
  count   = var.create_service_account ? 1 : 0
  project = google_project_iam_member.cluster_service_account_metric_writer[0].project
  role    = "roles/monitoring.viewer"
  member  = google_service_account.cluster_service_account[0].member
}

resource "google_project_iam_member" "cluster_service_account_resourceMetadata_writer" {
  count   = var.create_service_account ? 1 : 0
  project = google_project_iam_member.cluster_service_account_monitoring_viewer[0].project
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = google_service_account.cluster_service_account[0].member
}

resource "google_project_iam_member" "cluster_service_account_gcr" {
  for_each = var.create_service_account && var.grant_registry_access ? toset(local.registry_projects_list) : []
  project  = each.key
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${google_service_account.cluster_service_account[0].email}"
}

resource "google_project_iam_member" "cluster_service_account_artifact_registry" {
  for_each = var.create_service_account && var.grant_registry_access ? toset(local.registry_projects_list) : []
  project  = each.key
  role     = "roles/artifactregistry.reader"
  member   = "serviceAccount:${google_service_account.cluster_service_account[0].email}"
}

# To allow the GKE cluster to create and manage the firewall resources in the host project, 
# the GKE service account must be granted the Compute Security Admin
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam.html#google_project_iam_member
resource "google_project_iam_member" "gke_service_account_security_admin" {
  project = var.network_project_id
  member  = "serviceAccount:service-${var.project_number}@container-engine-robot.iam.gserviceaccount.com"
  role    = "roles/compute.securityAdmin"
}

resource "google_project_iam_member" "gke_service_account_service_agent_user" {
  project = var.network_project_id
  member  = "serviceAccount:service-${var.project_number}@container-engine-robot.iam.gserviceaccount.com"
  role    = "roles/container.hostServiceAgentUser"
}
