# ==============================================================================
# [compute.tf] GCP VPC 내에 K3s가 구동될 튼튼한 가상 머신(VM)을 띄웁니다.
# ==============================================================================

resource "google_compute_instance" "k3s_primary_node" {
  name         = "gcp-primary-k3s-node"
  
  # 아키텍트의 결단: 부하 테스트(JMeter)와 K3s 안정성을 위해 e2-standard-2(RAM 8GB) 선택
  # (Swap 메모리 같은 땜질식 처방 방지)
  machine_type = "e2-standard-2" 
  zone         = var.zone

  # OS 및 디스크 설정
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts" # 가장 안정적인 우분투 최신 버전
      size  = 50 # OS, K3s, 도커 이미지들이 넉넉히 숨쉴 수 있는 디스크 공간 (GB)
      type  = "pd-balanced" # 가격 대비 성능이 좋은 밸런스형 SSD
    }
  }

  # 네트워크 설정 (network.tf에서 만든 고정 IP를 여기에 꽂아줍니다)
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.k3s_static_ip.address
    }
  }

  # 이 서버의 꼬리표. network.tf의 방화벽이 이 꼬리표를 보고 길을 열어줍니다.
  tags = ["k3s-node"] 
  # 우분투(ubuntu)라는 이름표를 단 로봇만 이 자물쇠를 열 수 있다고 설정하는 겁니다.
  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}
