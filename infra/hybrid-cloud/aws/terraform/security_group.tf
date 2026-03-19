# -----------------------------------------------
# Bastion Host Security Group
# -----------------------------------------------
# 운영자 → Bastion → Monitoring Server / k3s 노드 접근 경로
# bastion_sg_id → 희정님 Monitoring Server SG ingress에 등록
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

  # 아웃바운드 전체 허용
  # Bastion → Monitoring Server / k3s 노드 접근 필요
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
# Cloudflare Tunnel 방식 → 인바운드 80/443 불필요
# cloudflared가 아웃바운드로 Cloudflare에 연결
resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-${var.environment}-k3s-sg"
  description = "Security group for k3s Standby Node"
  vpc_id      = aws_vpc.main.id

  # SSH - 운영자 IP만 허용
  ingress {
    description = "SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Kubernetes API - kubectl / CI-CD 배포용
  ingress {
    description = "Kubernetes API Server from operator"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Node Exporter - Prometheus 메트릭 수집
  # 희정님 Monitoring Server IP 확정 후 좁히기
  ingress {
    description = "Node Exporter for Prometheus"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: 희정님 IP 확정 후 수정
  }

  # VPC 내부 통신
  ingress {
    description = "Internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # 아웃바운드 전체 허용
  # cloudflared → Cloudflare 터널 연결
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
