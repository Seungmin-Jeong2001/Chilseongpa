Gemini의 응답
제공해주신 자료와 통합된 main.tf 구조에 맞춰, 각 모듈과 루트의 variables.tf 파일을 가장 깔끔하게 정리해 드립니다.

network 모듈이 사라지고 cloudflare 모듈이 중심이 됨에 따라, **변수의 흐름(Input/Output)**을 명확히 하는 것이 핵심입니다.

1. Root variables.tf (전체 프로젝트 컨트롤 타워)
모든 모듈에 공통으로 주입될 변수들을 정의합니다.

Terraform
# --- Global Variables ---
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "chilseongpa"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

# --- Cloudflare Configuration ---
variable "cf_api_token" {
  description = "Cloudflare API Token for Terraform"
  type        = string
  sensitive   = true
}

variable "cf_account_id" { type = string }
variable "cf_zone_id"    { type = string }
variable "cf_tunnel_secret" {
  type      = string
  sensitive = true
}

variable "app_domain" {
  default = "app.bucheongoyangijanggun.com"
}

variable "monitoring_domain" {
  default = "status.chilseongpa.com"
}

# --- AWS Configuration ---
variable "aws_region"            { default = "ap-northeast-2" }
variable "vpc_cidr"              { default = "10.20.0.0/16" }
variable "public_subnet_cidr"    { default = "10.20.1.0/24" }
variable "private_subnet_cidr"   { default = "10.20.2.0/24" }
variable "availability_zone"     { default = "ap-northeast-2a" }
variable "allowed_ssh_cidr"      { default = "0.0.0.0/0" }
variable "key_name"              { type = string }
variable "monitoring_ami_id"     { type = string }

# --- GCP Configuration ---
variable "gcp_project_id"   { type = string }
variable "gcp_region"       { default = "asia-northeast3" }
variable "gcp_zone"         { default = "asia-northeast3-a" }
variable "db_password"      { type = string; sensitive = true }
variable "gcp_credentials"  { type = string; sensitive = true }
2. modules/cloudflare/variables.tf
루트로부터 인증 정보와 도메인 정보를 받아 터널을 생성합니다.

Terraform
variable "cf_account_id"    { type = string }
variable "cf_zone_id"       { type = string }
variable "cf_tunnel_secret" { type = string; sensitive = true }
variable "project_name"     { type = string }
variable "environment"      { type = string }
variable "app_domain"       { type = string }
variable "monitoring_domain" { type = string }
3. modules/aws/variables.tf
네트워크(VPC) 생성 권한을 가졌으며, 클라우드플레어 터널 토큰을 주입받습니다.

Terraform
variable "project_name"       { type = string }
variable "environment"        { type = string }
variable "vpc_cidr"           { type = string }
variable "public_subnet_cidr" { type = string }
variable "availability_zone"  { type = string }
variable "allowed_ssh_cidr"   { type = string }
variable "key_name"           { type = string }

# Cloudflare로부터 전달받는 값
variable "tunnel_token" {
  type      = string
  sensitive = true
}
4. modules/monitoring/variables.tf
AWS 모듈로부터 네트워크 정보를, 클라우드플레어로부터 터널 정보를 받습니다.

Terraform
variable "project_name"       { type = string }
variable "environment"        { type = string }
variable "private_subnet_cidr" { type = string }
variable "availability_zone"  { type = string }
variable "ami_id"             { type = string }
variable "key_name"           { type = string }

# AWS 모듈로부터 전달받는 의존성 변수
variable "vpc_id"             { type = string }
variable "bastion_sg_id"      { type = string }

# Cloudflare로부터 전달받는 값
variable "tunnel_token" {
  type      = string
  sensitive = true
}

# 기본값 설정
variable "instance_type"    { default = "t3.small" }
variable "root_volume_size" { default = 30 }
variable "root_volume_type" { default = "gp3" }
5. modules/gcp/variables.tf
기존 설정을 유지하면서 터널 토큰 변수를 추가했습니다.

Terraform
variable "project_id"   { type = string }
variable "region"       { type = string }
variable "zone"         { type = string }
variable "db_password"  { type = string; sensitive = true }

# Cloudflare로부터 전달받는 값
variable "tunnel_token" {
  type      = string
  sensitive = true
}
💡 정리 포인트
중복 제거: network 모듈이 삭제됨에 따라 관련 변수들을 aws와 monitoring 모듈로 적절히 분배했습니다.

의존성 연결: monitoring 모듈이 aws 모듈의 결과물(vpc_id, bastion_sg_id)을 명확히 인지하도록 변수를 구성했습니다.

터널 토큰 표준화: 모든 컴퓨팅 모듈(aws, gcp, monitoring)이 tunnel_token이라는 동일한 이름의 변수를 입력받아 각자의 user_data에서 사용할 수 있게 했습니다.

이제 이 설정에 맞춰 각 모듈의 **outputs.tf**만 점검하면 테라폼 실행 준비가 완벽히 끝납니다. cloudflare 모듈의 outputs.tf 내용을 작성해 드릴까요?
(여기서 aws_tunnel_token, gcp_tunnel_token 등을 내보내야 루트에서 배분이 가능합니다.)