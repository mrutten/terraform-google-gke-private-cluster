resource "google_compute_shared_vpc_service_project" "service_project" {
  host_project    = var.network_project_id
  service_project = var.project_id
}

resource "google_compute_subnetwork_iam_member" "gke_api_service_agent" {
  member     = "serviceAccount:${var.project_number}@cloudservices.gserviceaccount.com"
  project    = var.network_project_id
  role       = "roles/compute.networkUser"
  region     = var.region
  subnetwork = var.subnetwork
}

resource "google_compute_subnetwork_iam_member" "gke_service_account" {
  member     = "serviceAccount:service-${var.project_number}@container-engine-robot.iam.gserviceaccount.com"
  project    = var.network_project_id
  role       = "roles/compute.networkUser"
  region     = var.region
  subnetwork = var.subnetwork
}
