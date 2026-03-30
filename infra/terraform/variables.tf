#root variables.tf

# -----------------------------------------------
# Global variables
# -----------------------------------------------

# main.tf에서 project_name, environment로 사용
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

# -----------------------------------------------
# GCP variables
# -----------------------------------------------
variable "gcp_project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "gcp_region" {
  description = "인프라가 배포될 리전"
  type        = string
  default     = "asia-northeast3"
}

variable "gcp_zone" {
  description = "인프라가 배포될 가용 영역"
  type        = string
  default     = "asia-northeast3-a"
}

variable "gcp_db_password" {
  description = "Cloud SQL Root 비밀번호"
  type        = string
  sensitive   = true
}

variable "gcp_credentials" {
  description = "GCP 인증 JSON (GitHub Actions에서 주입)"
  type        = string
  sensitive   = true
}

variable "gcp_ssh_public_key" {
  description = "Ansible 접속을 허용할 SSH 공개키(자물쇠)"
  type        = string
}

# -----------------------------------------------
# AWS variables
# -----------------------------------------------
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "vpc_cidr" {
  description = "AWS VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "AWS Public subnet CIDR block"
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  description = "AWS Private subnet CIDR block (k3s / Monitoring 배치)"
  type        = string
  default     = "10.20.2.0/24"
}

variable "availability_zone" {
  description = "AWS Availability zone"
  type        = string
  default     = "ap-northeast-2a"
}

# SSH 허용 CIDR
# GitHub Actions에서 MY_IP Secret으로 주입
variable "allowed_ssh_cidr" {
  description = "AWS CIDR block allowed to SSH"
  type        = string
  default     = "0.0.0.0/0"
}

# k3s 노드 인스턴스 타입
variable "instance_type" {
  description = "AWS k3s node EC2 instance type"
  type        = string
  default     = "t3.small"
}

# Bastion 인스턴스 타입 (트래픽 적으므로 t3.micro)
variable "bastion_type" {
  description = "AWS Bastion Host EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# Root EBS Volume 크기
variable "root_volume_size" {
  description = "AWS Root EBS volume size (GB)"
  type        = number
  default     = 20
}

# AWS 콘솔에서 미리 만들어둔 Key Pair 이름
variable "key_name" {
  description = "AWS Key Pair name"
  type        = string
}

# Monitoring Server 인스턴스 타입
variable "monitoring_instance_type" {
  description = "Monitoring Server EC2 instance type"
  type        = string
  default     = "t3.small"
}

# Monitoring Server EBS Volume 크기
# Prometheus TSDB 저장 공간 확보 목적
variable "monitoring_volume_size" {
  description = "Monitoring Server EBS volume size (GB)"
  type        = number
  default     = 30
}


# -----------------------------------------------
# Cloudflare variables
# -----------------------------------------------
variable "cf_api_token" {
  description = "Cloudflare API 토큰 (Terraform 실행용 권한)"
  type        = string
  sensitive   = true
}

variable "cf_account_id" {
  description = "Cloudflare 계정 ID"
  type        = string
}

variable "cf_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "cf_tunnel_secret" {
  description = "터널 생성 시 사용할 공통 Secret"
  type        = string
  sensitive   = true
}

# 기존의 https:// 와 끝의 / 를 모두 제거합니다.
variable "app_domain" {
  default = "app.bucheongoyangijanggun.com"
}

variable "monitoring_domain" {
  default = "monitoring.bucheongoyangijanggun.com"
}