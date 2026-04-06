# ==============================================================================
# [modules/gcp/outputs.tf] 
# ==============================================================================

output "k3s_ephemeral_ip" {
  description = "K3s 서버의 자동 할당된 공인 IP (Cloudflare 터널 연결 전 임시 확인용)"
  value       = google_compute_instance.k3s_primary_node.network_interface.0.access_config.0.nat_ip
}

output "k3s_internal_ip" {
  description = "K3s 서버 내부 IP (GCP 모니터링 VM에서 직접 scrape용)"
  value       = google_compute_instance.k3s_primary_node.network_interface.0.network_ip
}

output "monitoring_ephemeral_ip" {
  description = "GCP 모니터링 서버 공인 IP (Ansible 접속용)"
  value       = google_compute_instance.monitoring.network_interface.0.access_config.0.nat_ip
}

output "db_proxy_sa_key" {
  description = "정현님(AWS DB 연동)에게 전달할 Cloud SQL 접속용 JSON 키"
  value       = base64decode(google_service_account_key.db_proxy_sa_key.private_key)
  sensitive   = true # 터미널에 평문 노출 방지 (볼 때는 terraform output -raw db_proxy_sa_key 명령어 사용)
}

# 로컬 테스트를 위한 키 저장
resource "local_file" "db_proxy_sa_key_file" {
  content  = base64decode(google_service_account_key.db_proxy_sa_key.private_key)
  filename = "${path.root}/../ansible/roles/monitoring/files/gcp-sa-key.json"
}

output "db_instance_connection_name" {
  description = "앤서블에서 사용할 Cloud SQL 연결 이름"
  # 💡 리소스 이름이 'primary_db'이므로 아래와 같이 지정합니다.
  value       = google_sql_database_instance.primary_db.connection_name
}