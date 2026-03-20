# ==============================================================================
# [outputs.tf] 인프라 배포 후 아키텍트가 팀원들에게 불출할 결과물 목록
# ==============================================================================

output "k3s_static_ip" {
  description = "K3s 서버의 고정 IP"
  value       = google_compute_address.k3s_static_ip.address
}

output "db_proxy_sa_key" {
  description = "정현님(AWS DB 연동)에게 전달할 Cloud SQL 접속용 JSON 키"
  value       = base64decode(google_service_account_key.db_proxy_sa_key.private_key)
  sensitive   = true # 터미널에 평문 노출 방지 (볼 때는 terraform output -raw db_proxy_sa_key 명령어 사용)
}

# 🗑️ monitoring_sa_key 부분은 Cloudflare Tunnel 도입으로 인해 완전히 삭제!
