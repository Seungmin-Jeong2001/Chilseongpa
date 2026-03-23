terraform {
  required_providers {
    # 1. GCP 리소스 관리용 (필수)
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    
    # 2. IAM 전파 대기용 (우리가 추가한 핵심 방어막)
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}
