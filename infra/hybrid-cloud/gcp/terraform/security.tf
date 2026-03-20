# ------------------------------------------------------------------------------
# 1. Cloud SQL Auth Proxy용 계정 및 키 관리
# ------------------------------------------------------------------------------
resource "google_service_account" "db_proxy_sa" {
  account_id   = "gcp-db-proxy-sa"
  display_name = "For Cloud SQL Auth Proxy"
}

resource "time_sleep" "wait_30_seconds_db" {
  depends_on      = [google_service_account.db_proxy_sa]
  create_duration = "30s"
}

resource "google_project_iam_member" "db_proxy_sa_role" {
  depends_on = [time_sleep.wait_30_seconds_db]
  project    = var.project_id
  role       = "roles/cloudsql.client"
  member     = "serviceAccount:${google_service_account.db_proxy_sa.email}"
}

resource "google_service_account_key" "db_proxy_sa_key" {
  depends_on         = [google_project_iam_member.db_proxy_sa_role]
  service_account_id = google_service_account.db_proxy_sa.name
}

resource "google_secret_manager_secret" "db_proxy_key_secret" {
  secret_id  = "gcp-db-proxy-key-json"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_proxy_key_version" {
  secret      = google_secret_manager_secret.db_proxy_key_secret.id
  secret_data = base64decode(google_service_account_key.db_proxy_sa_key.private_key)
  depends_on  = [google_service_account_key.db_proxy_sa_key]
}

# Prometheus 모니터링 서버의 접근을 허용하는 방화벽 규칙
resource "google_compute_firewall" "allow_node_exporter" {
  name    = "allow-node-exporter"
  network = google_compute_network.vpc_network.name # 성호 님 VPC 이름으로 확인하세요!

  allow {
    protocol = "tcp"
    ports    = ["9100"]
  }

  # 희정님(모니터링 서버)의 IP만 허용하는 게 보안상 가장 좋지만,
  # 현재 팀원 전체 내부 통신을 위해 일단 0.0.0.0/0 또는 내부망 대역을 넣습니다.
  source_ranges = ["0.0.0.0/0"] 
  target_tags   = ["k3s-node"] # 성호 님 VM에 설정된 태그와 맞춰야 합니다!
}
