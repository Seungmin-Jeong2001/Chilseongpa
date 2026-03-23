resource "aws_instance" "monitoring_server" {

  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id = var.subnet_id
  key_name  = var.key_name

  # Monitoring Server 접근 제어
  vpc_security_group_ids = [
    aws_security_group.monitoring_sg.id
  ]

  # Root EBS Volume 설정
  root_block_device {
    # gp3 범용 SSD 스토리지
    volume_type = var.root_volume_type
    # Prometheus TSDB 및 로그 저장 공간 확보
    volume_size = var.root_volume_size
    
    # EC2 종료 시 볼륨 삭제 방지 (보류)
	  # delete_on_termination = false
  }
  # EC2 부팅 시 실행되는 초기화 스크립트
  # t3.small (2GB RAM) 환경에서 OOM 방지를 위해 Swap 구성
  user_data = <<-EOF
              #!/bin/bash

              # Swap 파일이 없을 때만 생성
              if [ ! -f /swapfile ]; then
                fallocate -l 2G /swapfile
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
              fi

              # 재부팅 시에도 Swap 유지
              grep -q '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
              # cloudflared 설치 및 실행
              curl -L -o cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
              dpkg -i cloudflared.deb
              # 루트에서 전달받은 토큰으로 터널 실행
              cloudflared service install ${var.tunnel_token}
}
              EOF

  tags = {
    Name = var.server_name
  }
}