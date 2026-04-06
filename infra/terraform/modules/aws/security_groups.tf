# ==============================================================================
# [modules/aws/security_groups.tf] 
# ==============================================================================


# -----------------------------------------------
# k3s 노드 Security Group
# -----------------------------------------------
# Bastion 제거 후 Public Subnet 배치 → 외부 직접 접근 허용
resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-${var.environment}-k3s-sg"
  description = "Security group for k3s Standby Node (Public Access)"
  vpc_id      = aws_vpc.main.id

  # SSH - 테스트 목적으로 0.0.0.0/0 허용
  ingress {
    description     = "SSH from anywhere"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = [var.allowed_ssh_cidr]
  }

  # Kubernetes API - VPC 내부에서만 접근 (필요 시 외부 허용 가능)
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

  # 아웃바운드 전체 허용
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
