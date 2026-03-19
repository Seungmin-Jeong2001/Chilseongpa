# -----------------------------------------------
# Ubuntu 22.04 LTS AMI (동적 조회) .
# SSM Parameter Store에서 최신 AMI ID 가져옴
# -----------------------------------------------
data "aws_ssm_parameter" "ubuntu_2204" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# -----------------------------------------------
# Bastion Host
# -----------------------------------------------
# Public Subnet 배치
# 운영자 → Bastion → Monitoring Server(Private) 접근 경로
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.ubuntu_2204.value
  instance_type               = var.bastion_instance_type
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
# k3s Standby Node
# -----------------------------------------------
# Public Subnet 배치 (Cloudflare Tunnel → 인바운드 포트 불필요)
# k3s / cloudflared / node-exporter 실행
# -----------------------------------------------
# Ansible Inventory 자동 생성 (로컬 실행 전용)
# -----------------------------------------------
# terraform apply 완료 후 ansible/inventory.ini 자동 생성
# GitHub Actions에서는 workflow에서 inventory를 별도로 생성하므로 사용 안 함
# local provider 필요 → main.tf required_providers에 추가되어 있음
resource "local_file" "ansible_inventory" {
  content = <<-EOT
    [aws_standby]
    ${aws_instance.k3s.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/${var.key_name}.pem ansible_ssh_extra_args='-o StrictHostKeyChecking=no'
  EOT
  filename = "${path.module}/../ansible/inventory.ini"
}

resource "aws_instance" "k3s" {
  ami                         = data.aws_ssm_parameter.ubuntu_2204.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.k3s.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

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
}
