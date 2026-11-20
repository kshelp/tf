terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}

variable "project" {
  type        = string
  description = "GCP 프로젝트 ID"
}

variable "credentials_file" {
  type        = string
  description = "서비스 계정 키(JSON) 경로. 빈 값이면 ADC(gcloud auth application-default login)를 사용"
  default     = ""
}

provider "google" {
  project     = var.project
  region      = "asia-northeast3"
  zone        = "asia-northeast3-c"
  credentials = var.credentials_file == "" ? null : file(var.credentials_file)
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
    access_config {} # 임시 외부 IP 할당
  }

  labels = {
    managed-by = "terraform"
  }
}

output "external_ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}
