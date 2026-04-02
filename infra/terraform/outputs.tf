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
# GCP Monitoring Server outputs
# -----------------------------------------------
output "gcp_monitoring_ephemeral_ip" {
  description = "GCP Monitoring Server Public IP (Ansible 접속용)"
  value       = module.gcp.monitoring_ephemeral_ip
}

output "ssh_commands" {
  description = "Convenient SSH commands"
  value = <<EOT
================ SSH ACCESS ================


# SSH Agent 시작 및 키 추가 (로컬에서 실행)
eval $(ssh-agent -s) \
ssh-add ../../chilseongpa_keypair.pem \
ssh-add ../../my_gcp_key \
ssh-add -l

# 변수 주입
set -a \
source ./group_vars/.env \
set +a \
echo $DISCORD_BOT_TOKEN

# Bastion Host
ssh -i ../../chilseongpa_keypair.pem ubuntu@${module.aws.bastion_public_ip}

# k3s Node (via Bastion)
ssh -i ../../chilseongpa_keypair.pem -A -J ubuntu@${module.aws.bastion_public_ip} ubuntu@${module.aws.k3s_private_ip}

# GCP k3s
ssh -i ~/my_gcp_key ubuntu@${module.gcp.k3s_ephemeral_ip}

# GCP Monitoring
ssh -i ~/my_gcp_key ubuntu@${module.gcp.monitoring_ephemeral_ip}

===========================================
EOT
}