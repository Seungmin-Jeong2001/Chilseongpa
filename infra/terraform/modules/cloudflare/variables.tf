# 프로젝트 공통 변수 (네이밍 컨벤션용)
variable "project_name" { type = string }
variable "environment"  { type = string }

# Cloudflare 인증 및 관리 정보
variable "cf_account_id" {
  description = "Cloudflare 계정 ID (Zero Trust 관리용)"
  type        = string
}

variable "cf_zone_id" {
  description = "도메인이 등록된 Cloudflare Zone ID"
  type        = string
}

# 터널 보안 정보
variable "cf_tunnel_secret" {
  description = "터널 암호화를 위한 32바이트 이상의 비밀 키"
  type        = string
  sensitive   = true
}

# 서비스 도메인 정보
variable "app_domain" {
  description = "GCP(Main)와 AWS(Standby)가 연결될 메인 서비스 도메인"
  type        = string
}

variable "grafana_domain" {
  description = "Grafana에 접근할 도메인"
  type        = string
}

variable "prometheus_domain" {
  description = "Prometheus에 접근할 도메인"
  type        = string
  
}
variable "cf_discord_webhook_url" {
  description = "Discord Webhook URL for Cloudflare Alerts"
  type        = string
  sensitive   = true
}