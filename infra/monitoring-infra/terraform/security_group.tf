resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring-server-sg"
  description = "Security group for Monitoring Server"
  vpc_id      = var.vpc_id

  # SSH (운영자 공인 IP)
  ingress {
    description = "Admin SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ip_list
  }

  # Grafana UI
  ingress {
    description = "Grafana UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.ip_list
  }

  # Prometheus UI
  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.ip_list
  }

  # Alertmanager UI
  ingress {
    description = "Alertmanager UI"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = var.ip_list
  }

  # Prometheus scrape via VPN
  ingress {
    description = "Prometheus scrape via VPN"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.vpn_cidr
  }

  # App metrics via VPN
  ingress {
    description = "App metrics via VPN"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.vpn_cidr
  }

  # 모든 outbound 트래픽 허용
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