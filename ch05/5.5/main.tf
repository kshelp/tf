terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

# 1) 필요한 Google API 활성화
resource "google_project_service" "enable_services" {
  for_each = toset([
    "container.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false # destroy 시 API는 비활성화하지 않음
  project            = var.project
}

# 2) VPC와 서브넷
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
  project                 = var.project

  depends_on = [google_project_service.enable_services]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project
}

# 3) 노드용 서비스 계정과 최소 권한
resource "google_service_account" "gke_node_sa" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Node service account for ${var.cluster_name}"
  project      = var.project

  depends_on = [google_project_service.enable_services]
}

resource "google_project_iam_member" "node_sa_node_role" {
  project = var.project
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "node_sa_compute_admin" {
  project = var.project
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "node_sa_logging" {
  project = var.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "node_sa_monitoring" {
  project = var.project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# 4) GKE 클러스터 (리전 클러스터)
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  project  = var.project
  location = var.region # 리전을 지정하면 리전 클러스터가 된다

  network    = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet.self_link

  # 기본 노드 풀은 제거하고 별도 노드 풀로 관리
  remove_default_node_pool = true
  initial_node_count       = 1

  min_master_version = var.master_version != "" ? var.master_version : null

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # google 프로바이더 5.0+는 기본값이 true라서 destroy가 거부된다. 실습용으로 해제
  deletion_protection = false

  depends_on = [google_project_service.enable_services]
}

# 5) 관리형 노드 풀
resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.cluster_name}-nodepool"
  project  = var.project
  location = var.region
  cluster  = google_container_cluster.primary.name

  node_count     = var.node_count # 영역(zone)당 노드 수
  node_locations = var.node_locations

  node_config {
    machine_type    = var.machine_type
    service_account = google_service_account.gke_node_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_size_gb    = 50 # 기본 100GB → 50GB
    disk_type       = "pd-balanced"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  depends_on = [
    google_project_iam_member.node_sa_node_role,
  ]
}
