resource "aws_security_group" "monitoring_sg" {

  name        = "monitoring-server-sg"
  description = "Security group for Monitoring Server"
  
  # Security Group을 생성할 VPC
  vpc_id = var.vpc_id
  
  # SSH
  ingress {
    description = "Admin SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # Bastion SG 허용
		security_groups = [var.bastion_sg_id]
  }

  # Grafana
  ingress {
    description = "Grafana UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [var.bastion_sg_id]
  }
  
  # Prometheus UI
  ingress {
	  description = "Prometheus UI"
	  from_port   = 9090
	  to_port     = 9090
	  protocol    = "tcp"
	  security_groups = [var.bastion_sg_id]
	}

  # Alertmanager UI
  ingress {
    description = "Alertmanager UI"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    security_groups = [var.bastion_sg_id]
  }

  # outbound only
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "monitoring-server-sg"
  }
}