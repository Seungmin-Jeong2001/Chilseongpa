# -----------------------------------------------
# GCP Primary outputs
# -----------------------------------------------
output "gcp_k3s_ephemeral_ip" {
  description = "GCP K3s 임시 공인 IP (Ansible 초기 접속용)"
  value       = module.gcp.k3s_ephemeral_ip
}

output "gcp_db_proxy_sa_key" {
  description = "AWS DB 연동을 위한 Cloud SQL Proxy JSON 키"
  value       = module.gcp.db_proxy_sa_key
  sensitive   = true
}

# -----------------------------------------------
# AWS Network outputs
# -----------------------------------------------
output "aws_vpc_id" {
  description = "AWS VPC ID"
  value       = module.aws.vpc_id
}

output "aws_public_subnet_id" {
  description = "AWS Public Subnet ID"
  value       = module.aws.public_subnet_id
}

output "aws_private_subnet_id" {
  description = "AWS Private Subnet ID"
  value       = module.aws.private_subnet_id
}

# -----------------------------------------------
# AWS Bastion outputs
# -----------------------------------------------
output "aws_bastion_sg_id" {
  description = "AWS Bastion SG ID"
  value       = module.aws.bastion_sg_id
}

output "aws_bastion_public_ip" {
  description = "AWS Bastion Host Public IP"
  value       = module.aws.bastion_public_ip
}

# -----------------------------------------------
# AWS k3s node outputs
# -----------------------------------------------
output "aws_k3s_private_ip" {
  description = "AWS k3s Node Private IP (Bastion 경유 접속)"
  value       = module.aws.k3s_private_ip
}

output "aws_standby_security_group_id" {
  description = "AWS k3s 노드 Security Group ID"
  value       = module.aws.standby_security_group_id
}

# -----------------------------------------------
# AWS Monitoring Server outputs
# -----------------------------------------------
output "aws_monitoring_private_ip" {
  description = "AWS Monitoring Server Private IP"
  value       = module.aws.monitoring_private_ip
}

output "aws_monitoring_instance_id" {
  description = "AWS Monitoring Server EC2 Instance ID"
  value       = module.aws.monitoring_instance_id
}
