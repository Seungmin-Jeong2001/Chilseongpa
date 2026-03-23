# -----------------------------------------------
# Network outputs
# monitoring 모듈에서 vpc_id 참조용
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

# -----------------------------------------------
# Bastion outputs
# -----------------------------------------------
# 희정님 → Monitoring Server SG ingress에 등록
output "bastion_sg_id" {
  description = "Bastion SG ID → 희정님 Monitoring Server SG에 등록"
  value       = aws_security_group.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion Host Public IP"
  value       = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "Bastion SSH 접속 명령어"
  value       = "ssh -i ~/.ssh/<your-key>.pem ubuntu@${aws_instance.bastion.public_ip}"
}

# -----------------------------------------------
# k3s node outputs
# -----------------------------------------------
output "k3s_instance_id" {
  description = "k3s Node EC2 Instance ID"
  value       = aws_instance.k3s.id
}

# 희정님 → Prometheus Node Exporter scrape 대상
output "k3s_public_ip" {
  description = "k3s Node Public IP"
  value       = aws_instance.k3s.public_ip
}

output "k3s_ssh_command" {
  description = "k3s Node SSH 접속 명령어"
  value       = "ssh -i ~/.ssh/<your-key>.pem ubuntu@${aws_instance.k3s.public_ip}"
}

# Ansible workflow에서 SSH 임시 허용용
output "standby_security_group_id" {
  description = "k3s 노드 Security Group ID"
  value       = aws_security_group.k3s.id
}