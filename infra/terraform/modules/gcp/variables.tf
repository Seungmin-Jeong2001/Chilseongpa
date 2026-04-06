# 
# ==============================================================================
# [variables.tf] 하드코딩을 방지하고, 환경(Dev/Prod)이 바뀔 때 유연하게 
# 대처하기 위해 사용하는 변수 저장소입니다.
# ==============================================================================

# --- 네이밍 규칙을 위한 공통 변수 (추가) ---
variable "project_name" {
  description = "프로젝트 이름 (리소스 네이밍 접두어)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (예: dev, prod, standby)"
  type        = string
}

# --- GCP 인프라 설정 변수 ---
variable "gcp_project_id" {
  description = "GCP 프로젝트 ID (GitHub Secrets: TF_VAR_project_id에서 보안 주입)"
  type        = string
}

variable "gcp_region" {
  description = "인프라가 배포될 리전 (AWS와 통신 지연을 막기 위해 서울로 고정)"
  type        = string
  default     = "asia-northeast3" # 아키텍트의 결정: 서울 리전
}

variable "gcp_zone" {
  description = "인프라가 배포될 가용 영역"
  type        = string
  default     = "asia-northeast3-a"
}

variable "gcp_subnet_cidr" {
  description = "GCP 서브넷 CIDR (AWS 10.20.0.0/16과 충돌 없는 대역)"
  type        = string
  default     = "10.30.0.0/24"
}

variable "gcp_credentials" {
  description = "GCP 인증 JSON (GitHub Actions에서 주입)"
  type        = string
  sensitive   = true
}

# --- 보안 및 인증 변수 ---
variable "gcp_db_password" {
  description = "Cloud SQL Root 비밀번호 (GitHub Secrets: TF_VAR_db_password를 통해 주입)"
  type        = string
  sensitive   = true # 비밀번호가 로그나 화면에 노출되는 것을 방지
}

variable "gcp_ssh_public_key" {
  description = "Ansible 접속을 허용할 SSH 공개키(자물쇠)"
  type        = string
}

# --- Cloudflare 연결 변수 ---
variable "tunnel_token" {
  description = "Cloudflare Tunnel Token for GCP Instance"
  type        = string
  sensitive   = true
}

variable "monitoring_tunnel_token" {
  description = "Cloudflare Tunnel Token for GCP Monitoring Instance"
  type        = string
  sensitive   = true
}
