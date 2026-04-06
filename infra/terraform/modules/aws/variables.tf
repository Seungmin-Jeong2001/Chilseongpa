# ==============================================================================
# [modules/aws/variables.tf] 
# ==============================================================================


variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# -----------------------------------------------
# Network 변수
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

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH"
  type        = string
  default     = "0.0.0.0/0"
}

# -----------------------------------------------
# EC2 변수
# -----------------------------------------------
variable "key_name" {
  description = "AWS Key Pair name"
  type        = string
}

variable "instance_type" {
  description = "k3s node EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Root EBS volume size (GB)"
  type        = number
  default     = 20
}

# -----------------------------------------------
# Cloudflare 터널 토큰
# -----------------------------------------------
variable "aws_tunnel_token" {
  description = "AWS K3s용 터널 토큰"
  type        = string
}
