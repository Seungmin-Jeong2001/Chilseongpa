variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "hybrid-project"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "aws-standby"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block"
  type        = string
  default     = "10.20.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "ap-northeast-2a"
}

# SSH 허용 CIDR
# GitHub Actions에서 MY_IP Secret으로 주입
variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH"
  type        = string
  default     = "0.0.0.0/0"
}

# k3s 노드 인스턴스 타입
variable "instance_type" {
  description = "k3s node EC2 instance type"
  type        = string
  default     = "t3.small"
}

# Bastion 인스턴스 타입 (트래픽 적으므로 t3.micro)
variable "bastion_instance_type" {
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

# AWS 콘솔에서 미리 만들어둔 Key Pair 이름
variable "key_name" {
  description = "AWS Key Pair name"
  type        = string
}
