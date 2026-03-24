# -------------------------------------------------------------------
# Cloudflare Tunnel Tokens
# 이 토큰들은 각 인스턴스의 user_data에서 터널을 실행하는 데 사용됩니다.
# -------------------------------------------------------------------

output "aws_tunnel_token" {
  description = "AWS Standby 노드용 터널 토큰"
  value       = cloudflare_zero_trust_tunnel_cloudflared.tunnels["aws"].tunnel_token
  sensitive   = true
}

output "gcp_tunnel_token" {
  description = "GCP Primary 노드용 터널 토큰"
  value       = cloudflare_zero_trust_tunnel_cloudflared.tunnels["gcp"].tunnel_token
  sensitive   = true
}

output "monitoring_tunnel_token" {
  description = "AWS Monitoring 서버용 터널 토큰"
  value       = cloudflare_zero_trust_tunnel_cloudflared.tunnels["monitoring"].tunnel_token
  sensitive   = true
}

# -------------------------------------------------------------------
# Cloudflare Tunnel IDs (필요 시 참조용)
# -------------------------------------------------------------------

output "aws_tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.tunnels["aws"].id
}

output "gcp_tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.tunnels["gcp"].id
}

output "monitoring_tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.tunnels["monitoring"].id
}
output "cf_access_client_id" {
  value = cloudflare_zero_trust_access_service_token.monitoring_token.client_id
}

output "cf_access_client_secret" {
  value     = cloudflare_zero_trust_access_service_token.monitoring_token.client_secret
  sensitive = true
}