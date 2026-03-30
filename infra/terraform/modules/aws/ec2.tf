data "aws_ssm_parameter" "ubuntu_2204" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# -----------------------------------------------
# Bastion Host — Public Subnet
# -----------------------------------------------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.ubuntu_2204.value
  instance_type               = var.bastion_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    tags = {
      Name    = "${var.project_name}-${var.environment}-bastion-vol"
      Project = var.project_name
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion"
    Project     = var.project_name
    Environment = var.environment
    Role        = "bastion"
  }
}

# -----------------------------------------------
# k3s Standby Node — Private Subnet
# cloudflared → NAT Gateway → IGW → Cloudflare
# -----------------------------------------------
resource "aws_instance" "k3s" {
  ami                         = data.aws_ssm_parameter.ubuntu_2204.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.k3s.id]
  key_name                    = var.key_name
  associate_public_ip_address = false

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    tags = {
      Name    = "${var.project_name}-${var.environment}-k3s-vol"
      Project = var.project_name
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-k3s-node"
    Project     = var.project_name
    Environment = var.environment
    Role        = "standby"
  }

  user_data = <<-EOF
    #!/bin/bash
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared.deb
    cloudflared service install ${var.aws_tunnel_token}
  EOF
}

# -----------------------------------------------
# Monitoring Server — Private Subnet
# Prometheus / Grafana / Alertmanager / Discord Bot
# -----------------------------------------------
resource "aws_instance" "monitoring" {
  ami                         = data.aws_ssm_parameter.ubuntu_2204.value
  instance_type               = var.monitoring_instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.monitoring.id]
  key_name                    = var.key_name
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    # 1. Swap 구성 (OOM 방지)
    if [ ! -f /swapfile ]; then
      fallocate -l 2G /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      grep -q '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    # 2. Cloudflare Tunnel 설치
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared.deb
    cloudflared service install ${var.monitoring_tunnel_token}
  EOF

  root_block_device {
    volume_size           = var.monitoring_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    tags = {
      Name    = "${var.project_name}-${var.environment}-monitoring-vol"
      Project = var.project_name
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring"
    Project     = var.project_name
    Environment = var.environment
    Role        = "monitoring"
  }
}

# 모니터링 수집기 볼륨
resource "aws_ebs_volume" "monitoring_data" {
  availability_zone = var.availability_zone
  size              = 20
}
# 뷸륨 결착
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh" # OS에서는 nvme1n1 등으로 보일 수 있음
  volume_id   = aws_ebs_volume.monitoring_data.id
  instance_id = aws_instance.monitoring.id
}
