# ==============================================================================
# [network.tf] GCP 커스텀 VPC / 서브넷 / 방화벽 규칙
# ==============================================================================

# -------------------------------------------------------------------
# VPC
# -------------------------------------------------------------------
resource "google_compute_network" "vpc" {
  name                    = "${var.project_name}-${var.environment}-vpc"
  auto_create_subnetworks = false
}

# -------------------------------------------------------------------
# Subnet
# -------------------------------------------------------------------
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_name}-${var.environment}-subnet"
  ip_cidr_range = var.gcp_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.vpc.id
}

# -------------------------------------------------------------------
# 방화벽: SSH (k3s-node, monitoring-node 공통)
# -------------------------------------------------------------------
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.project_name}-${var.environment}-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["k3s-node", "monitoring-node"]
  source_ranges = ["0.0.0.0/0"]
}

# -------------------------------------------------------------------
# 방화벽: 내부 메트릭 수집 (monitoring-node → k3s-node)
# Node Exporter(9100), App metrics NodePort(30800), kube-state-metrics NodePort(30080)
# -------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal_metrics" {
  name    = "${var.project_name}-${var.environment}-allow-internal-metrics"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["9100", "30800", "30080"]
  }

  target_tags = ["k3s-node"]
  source_tags = ["monitoring-node"]
}
