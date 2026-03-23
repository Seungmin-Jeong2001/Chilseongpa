# modules/aws/variables.tf

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# -----------------------------------------------
# Network 변수 (network.tf에서 사용)
# -----------------------------------------------
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
}

# SSH 허용 CIDR
# GitHub Actions에서 MY_IP Secret으로 주입
variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH"
  type        = string
  default     = "0.0.0.0/0"
}

# -----------------------------------------------
# EC2 변수 (ec2.tf에서 사용)
# -----------------------------------------------
# AWS 콘솔에서 미리 만들어둔 Key Pair 이름
variable "key_name" {
  description = "AWS Key Pair name"
  type        = string
}

# k3s 노드 인스턴스 타입
variable "instance_type" {
  description = "k3s node EC2 instance type"
  type        = string
  default     = "t3.small"
}

# Bastion 인스턴스 타입 (트래픽 적으므로 t3.micro)
variable "bastion_type" {
  description = "Bastion Host EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# Root EBS Volume 크기
variable "root_volume_size" {
  description = "Root EBS volume size (GB)"
  type        = number
  default     = 20
}

# -----------------------------------------------
# Cloudflare 터널 토큰 (cloudflare 모듈에서 전달받음)
# -----------------------------------------------
variable "tunnel_token" {
  description = "Cloudflare Tunnel token for cloudflared Pod"
  type        = string
  sensitive   = true
}