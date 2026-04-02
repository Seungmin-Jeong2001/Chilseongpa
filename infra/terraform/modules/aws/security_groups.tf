# -----------------------------------------------
# Bastion Host Security Group
# -----------------------------------------------
# 외부에서 SSH 접근 가능한 유일한 서버
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for Bastion Host"
  vpc_id      = aws_vpc.main.id

  # SSH - 운영자 IP만 허용
  ingress {
    description = "SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-bastion-sg"
    Project     = var.project_name
    Environment = var.environment
    Role        = "bastion"
  }
}

# -----------------------------------------------
# k3s 노드 Security Group
# -----------------------------------------------
# Private Subnet 배치 → 외부 직접 접근 없음
# SSH는 Bastion SG 경유만 허용
resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-${var.environment}-k3s-sg"
  description = "Security group for k3s Standby Node"
  vpc_id      = aws_vpc.main.id

  # SSH - Bastion SG 경유만 허용 (외부 직접 SSH 차단)
  ingress {
    description     = "SSH via Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Kubernetes API - VPC 내부에서만 접근
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # Node Exporter - Prometheus 메트릭 수집 (VPC 내부)
  ingress {
    description = "Node Exporter for Prometheus"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # VPC 내부 통신
  ingress {
    description = "Internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # 아웃바운드 전체 허용 (NAT Gateway 경유)
  # cloudflared → Cloudflare Tunnel 연결
  # GCP Cloud SQL 접근
  # 패키지 설치 등
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-k3s-sg"
    Project     = var.project_name
    Environment = var.environment
    Role        = "k3s-standby"
  }
}

