# AWS Monitoring Server 배포에 필요한 변수들 정의
# AWS Region
# 실제 AWS 배포 환경에서 사용할 리전
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# EC2 인스턴스 타입
# Monitoring Server 운영 스펙
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

# Root EBS Volume 크기
# Prometheus TSDB 저장 공간 확보 목적
variable "root_volume_size" {
  description = "Root EBS volume size"
  type        = number
  default     = 30
}

# Root EBS Volume 타입
# gp3는 비용 대비 성능이 안정적인 범용 SSD 스토리지
variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

# EC2 Name Tag
# AWS Console에서 인스턴스를 식별하기 위한 Tag
variable "server_name" {
  description = "EC2 instance name"
  type        = string
  default     = "Monitoring-Server"
}

# AMI ID
# Ubuntu 22.04 LTS AMI 사용
variable "ami_id" {
  description = "AMI ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC where monitoring server will be deployed"
  type        = string
}

# EC2 배치 Subnet
variable "subnet_id" {
  description = "Subnet where monitoring server will be deployed"
  type        = string
}

# SSH Key Pair
variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "bastion_sg_id" {
  description = "Security Group ID of Bastion Host"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "monitoring_domain" {
  description = "Domain name for Grafana/Prometheus (예: monitor.yourdomain.com)"
  type        = string
}

variable "tunnel_token" {
  description = "Arbitrary 32-byte string for tunnel secret"
  type        = string
  sensitive   = true
}