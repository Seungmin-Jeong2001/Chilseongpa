output "instance_type" {
  description = "Monitoring Server EC2 instance type"
  value       = aws_instance.monitoring_server.instance_type
}

# Root EBS Volume 크기 출력
output "root_volume_size" {
  description = "Monitoring Server root volume size"
  value       = var.root_volume_size
}

# 생성된 Security Group ID 출력
output "security_group_id" {
  description = "Monitoring Server security group id"
  value       = aws_security_group.monitoring_sg.id
}