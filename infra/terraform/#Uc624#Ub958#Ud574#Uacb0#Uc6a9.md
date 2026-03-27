# -----------------------------------------------
# Bastion Host Security Group
# -----------------------------------------------
# 운영자 → Bastion, k3s 노드 / Monitoring Server 접근 경로
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
    cidr_blocks = [aws_security_group.bastion.id]
  }

  # Kubernetes API - kubectl / CI-CD 배포용
  ingress {
    description = "Kubernetes API Server from operator"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.bastion.id]
  }

  # Node Exporter - Prometheus 메트릭 수집
  # Monitoring Server와 같은 VPC 내에 있으므로 VPC CIDR로 제한
  ingress {
    description = "Node Exporter for Prometheus"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.bastion.id]
  }

  # VPC 내부 통신
  ingress {
    description = "Internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_security_group.bastion.id]
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

# -----------------------------------------------
# Monitoring Server Security Group
# -----------------------------------------------
# Bastion을 통해서만 접근 허용
# Prometheus outbound로 메트릭 수집 (inbound 불필요)
resource "aws_security_group" "monitoring" {
  name        = "${var.project_name}-${var.environment}-monitoring-sg"
  description = "Security group for Monitoring Server"
  vpc_id      = aws_vpc.main.id

  # SSH - Bastion SG에서만 허용
  ingress {
    description     = "Admin SSH access via Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Grafana UI - Bastion SG에서만 허용
  ingress {
    description     = "Grafana UI"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Prometheus UI - Bastion SG에서만 허용
  ingress {
    description     = "Prometheus UI"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Alertmanager UI - Bastion SG에서만 허용
  ingress {
    description     = "Alertmanager UI"
    from_port       = 9093
    to_port         = 9093
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # 아웃바운드 전체 허용
  # Prometheus → Node Exporter scrape
  # cloudflared → Cloudflare 터널 연결
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-monitoring-sg"
    Project     = var.project_name
    Environment = var.environment
    Role        = "monitoring"
  }
}

##위와 같이 대충 바꿧더니 오류 생겼습니다

module.gcp.google_sql_user.root_user: Creation complete after 1s [id=root//hybrid-primary-db]
╷
│ Error: "sg-03d5c7e7ed39fb3bb" is not a valid CIDR block: invalid CIDR address: sg-03d5c7e7ed39fb3bb
│ 
│   with module.aws.aws_security_group.k3s,
│   on modules/aws/security_groups.tf line 41, in resource "aws_security_group" "k3s":
│   41: resource "aws_security_group" "k3s" {
│ 
╵
╷
│ Error: "sg-03d5c7e7ed39fb3bb" is not a valid CIDR block: invalid CIDR address: sg-03d5c7e7ed39fb3bb
│ 
│   with module.aws.aws_security_group.k3s,
│   on modules/aws/security_groups.tf line 41, in resource "aws_security_group" "k3s":
│   41: resource "aws_security_group" "k3s" {
│ 
╵
╷
│ Error: "sg-03d5c7e7ed39fb3bb" is not a valid CIDR block: invalid CIDR address: sg-03d5c7e7ed39fb3bb
│ 
│   with module.aws.aws_security_group.k3s,
│   on modules/aws/security_groups.tf line 41, in resource "aws_security_group" "k3s":
│   41: resource "aws_security_group" "k3s" {
│ 
╵
╷
│ Error: "sg-03d5c7e7ed39fb3bb" is not a valid CIDR block: invalid CIDR address: sg-03d5c7e7ed39fb3bb
│ 
│   with module.aws.aws_security_group.k3s,
│   on modules/aws/security_groups.tf line 41, in resource "aws_security_group" "k3s":
│   41: resource "aws_security_group" "k3s" {
│ 
╵
jeong@DESKTOP-G4U9APQ:~/github/Chilseongpa/infra/terraform$ ^C