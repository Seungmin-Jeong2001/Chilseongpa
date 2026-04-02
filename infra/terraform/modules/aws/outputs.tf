# -----------------------------------------------
# Network outputs
# -----------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Private Subnet ID"
  value       = aws_subnet.private.id
}

# -----------------------------------------------
# Bastion outputs
# -----------------------------------------------
output "bastion_sg_id" {
  description = "Bastion SG ID"
  value       = aws_security_group.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion Host Public IP"
  value       = aws_instance.bastion.public_ip
}

# -----------------------------------------------
# k3s node outputs
# -----------------------------------------------
output "k3s_instance_id" {
  description = "k3s Node EC2 Instance ID"
  value       = aws_instance.k3s.id
}

output "k3s_private_ip" {
  description = "k3s Node Private IP (Bastion 경유 접속)"
  value       = aws_instance.k3s.private_ip
}

output "standby_security_group_id" {
  description = "k3s 노드 Security Group ID"
  value       = aws_security_group.k3s.id
}

