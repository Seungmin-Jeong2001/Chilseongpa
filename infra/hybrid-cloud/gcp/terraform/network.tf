# ==============================================================================
# [network.tf] GCP 네트워크 및 기본 방화벽 설정
# ==============================================================================
resource "google_compute_address" "k3s_static_ip" {
  name   = "k3s-primary-static-ip"
  region = var.region
}

# -------------------------------------------------------------------------
# 🛡️ 방화벽: 관리자(Ansible) 초기 프로비저닝용 SSH 포트만 개방
# (향후 완벽한 터널링 구성 시 이 포트마저 닫고 IAP를 통해 접근 가능)
# -------------------------------------------------------------------------
resource "google_compute_firewall" "allow_admin_access" {
  name    = "allow-k3s-admin-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["k3s-node"]
  source_ranges = ["0.0.0.0/0"] # 주의: 실무에서는 특정 IP만 허용하도록 변경 필수
}
