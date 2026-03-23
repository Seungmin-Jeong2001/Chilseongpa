# # ==============================================================================
# # [compute.tf] GCP VPC 내에 K3s가 구동될 튼튼한 가상 머신(VM)을 띄웁니다.
# # ==============================================================================

# resource "google_compute_instance" "k3s_primary_node" {
#   name         = "gcp-primary-k3s-node"
  
#   # 아키텍트의 결단: 부하 테스트(JMeter)와 K3s 안정성을 위해 e2-standard-2(RAM 8GB) 선택
#   # (Swap 메모리 같은 땜질식 처방 방지)
#   machine_type = "e2-standard-2" 
#   zone         = var.gcp_zone

#   # OS 및 디스크 설정
#   boot_disk {
#     initialize_params {
#       image = "ubuntu-os-cloud/ubuntu-2204-lts" # 가장 안정적인 우분투 최신 버전
#       size  = 50 # OS, K3s, 도커 이미지들이 넉넉히 숨쉴 수 있는 디스크 공간 (GB)
#       type  = "pd-balanced" # 가격 대비 성능이 좋은 밸런스형 SSD
#     }
#   }

#   # 네트워크 설정
#   network_interface {
#     network = "default"

#     access_config {
      
#     }
#   }
#   # 이 서버의 꼬리표. network.tf의 방화벽이 이 꼬리표를 보고 길을 열어줍니다.
#   tags = ["k3s-node"] 
#   # 우분투(ubuntu)라는 이름표를 단 로봇만 이 자물쇠를 열 수 있다고 설정하는 겁니다.
#   metadata = {
#     ssh-keys = "ubuntu:${var.gcp_ssh_public_key}"
#   }
# }

# ==============================================================================
# [compute.tf] GCP VPC 내에 K3s가 구동될 가상 머신(VM)을 정의합니다.
# Cloudflare Tunnel을 통해 외부 포트 개방 없이 안전하게 연결됩니다.
# ==============================================================================

resource "google_compute_instance" "k3s_primary_node" {
  # 네이밍 규칙 적용: 팀 표준에 맞춰 식별력을 높입니다.
  name         = "${var.project_name}-${var.environment}-gcp-k3s-node"
  
  # 아키텍트의 결단: 부하 테스트와 안정성을 위해 사양 유지
  machine_type = "e2-standard-2" 
  zone         = var.gcp_zone

  # OS 및 디스크 설정
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-balanced"
    }
  }

  # 네트워크 설정
  network_interface {
    network = "default" # 추후 VPC 분리 시 수정 가능

    access_config {
      # 외부 IP 할당 (터널이 끊겼을 때의 비상용 또는 Ansible 접속용)
    }
  }

  # Cloudflare Tunnel 자동 설치 및 실행 스크립트 추가
  # 루트에서 전달받은 var.tunnel_token을 사용합니다.
  metadata_startup_script = <<-EOF
    #!/bin/bash
    # 1. cloudflared 패키지 다운로드 및 설치
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared.deb

    # 2. 전달받은 토큰으로 터널 서비스 설치 및 실행
    # 이 명령 한 줄로 별도의 설정 파일 없이 Cloudflare와 연결됩니다.
    cloudflared service install ${var.tunnel_token}
  EOF

  # 보안 및 식별 태그
  tags = ["k3s-node"] 

  # SSH 접속 설정 (루트 레벨에서 전달받은 공개키 사용)
  metadata = {
    ssh-keys = "ubuntu:${var.gcp_ssh_public_key}"
  }
}