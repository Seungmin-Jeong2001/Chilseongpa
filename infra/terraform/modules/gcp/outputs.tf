# ==============================================================================
# [outputs.tf] 인프라 배포 후 아키텍트가 팀원들에게 불출할 결과물 목록
# ==============================================================================

output "k3s_ephemeral_ip" {
  description = "K3s 서버의 자동 할당된 공인 IP (Cloudflare 터널 연결 전 임시 확인용)"
  value       = google_compute_instance.k3s_primary_node.network_interface.0.access_config.0.nat_ip
}

output "db_proxy_sa_key" {
  description = "정현님(AWS DB 연동)에게 전달할 Cloud SQL 접속용 JSON 키"
  value       = base64decode(google_service_account_key.db_proxy_sa_key.private_key)
  sensitive   = true # 터미널에 평문 노출 방지 (볼 때는 terraform output -raw db_proxy_sa_key 명령어 사용)
}

# 로컬 테스트를 위한 키 저장(CI/CD 떈.. 이거 어캄?)
resource "local_file" "db_proxy_sa_key_file" {
  content  = base64decode(google_service_account_key.db_proxy_sa_key.private_key)
  filename = "${path.root}/../ansible/roles/monitoring/files/gcp-sa-key.json"
}
# 🗑️ monitoring_sa_key 부분은 Cloudflare Tunnel 도입으로 인해 완전히 삭제!

output "db_instance_connection_name" {
  description = "앤서블에서 사용할 Cloud SQL 연결 이름"
  # 💡 리소스 이름이 'primary_db'이므로 아래와 같이 지정합니다.
  value       = google_sql_database_instance.primary_db.connection_name
}