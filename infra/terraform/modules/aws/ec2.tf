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
    encrypted             = true
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
    encrypted             = true
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
    if ! command -v cloudflared &>/dev/null; then
      curl -L --output /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
      dpkg -i /tmp/cloudflared.deb
      cloudflared service install ${var.aws_tunnel_token}
    fi
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
    if ! command -v cloudflared &>/dev/null; then
      curl -L --output /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
      dpkg -i /tmp/cloudflared.deb
      cloudflared service install ${var.monitoring_tunnel_token}
    fi
  EOF

  root_block_device {
    volume_size           = var.monitoring_volume_size
    volume_type           = "gp3"
    encrypted             = true
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

# -----------------------------------------------
# Monitoring Server — 데이터 EBS 볼륨 (Prometheus 영속 저장소)
# Nitro 기반(t3.small)에서 OS는 /dev/nvme1n1로 인식하지만
# Ubuntu 22.04 AMI는 amazon-ec2-utils의 udev rule로 /dev/sdh 심링크 제공
# -----------------------------------------------
resource "aws_ebs_volume" "monitoring_data" {
  availability_zone = var.availability_zone
  size              = 20
  type              = "gp3"
  encrypted         = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-data-vol"
    Project     = var.project_name
    Environment = var.environment
    Role        = "monitoring"
    ManagedBy   = "terraform"
  }
}

resource "aws_volume_attachment" "monitoring_data" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.monitoring_data.id
  instance_id = aws_instance.monitoring.id
}
