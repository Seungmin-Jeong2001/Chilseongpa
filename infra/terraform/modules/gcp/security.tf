
# ==============================================================================
# [modules/gcp/security.tf] GCP 보안 설정
# ==============================================================================

# ------------------------------------------------------------------------------
#  Cloud SQL Auth Proxy용 계정 및 키 관리
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
  project    = var.gcp_project_id
  role       = "roles/cloudsql.client"
  member     = "serviceAccount:${google_service_account.db_proxy_sa.email}"
}

resource "google_project_iam_member" "db_proxy_sa_monitoring_role" {
  depends_on = [time_sleep.wait_30_seconds_db]
  project    = var.gcp_project_id
  role       = "roles/monitoring.viewer"
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
