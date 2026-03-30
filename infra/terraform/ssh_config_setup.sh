#!/bin/bash
# -----------------------------------------------
# terraform apply 후 ~/.ssh/config 자동 생성
# 실행: bash ssh_config_setup.sh
# -----------------------------------------------

BASTION_IP=$(terraform output -raw aws_bastion_public_ip)
K3S_IP=$(terraform output -raw aws_k3s_private_ip)
MON_IP=$(terraform output -raw aws_monitoring_private_ip)
# 스크립트 위치(infra/terraform)에서 두 단계 위가 프로젝트 루트
KEY="$(cd "$(dirname "$0")/../.." && pwd)/chilseongpa_keypair.pem"

echo "Bastion IP  : $BASTION_IP"
echo "k3s IP      : $K3S_IP"
echo "Monitoring IP: $MON_IP"

# 기존 설정 제거 후 새로 추가
grep -v "Host bastion\|Host k3s\|Host monitoring\|HostName $BASTION_IP\|HostName $K3S_IP\|HostName $MON_IP" ~/.ssh/config > /tmp/ssh_config_tmp 2>/dev/null
mv /tmp/ssh_config_tmp ~/.ssh/config 2>/dev/null

cat >> ~/.ssh/config << SSHEOF

# -----------------------------------------------
# Chilseongpa AWS (자동 생성)
# -----------------------------------------------
Host bastion
  HostName $BASTION_IP
  User ubuntu
  IdentityFile $KEY
  StrictHostKeyChecking no

Host k3s
  HostName $K3S_IP
  User ubuntu
  IdentityFile $KEY
  ProxyJump bastion
  StrictHostKeyChecking no

Host monitoring
  HostName $MON_IP
  User ubuntu
  IdentityFile $KEY
  ProxyJump bastion
  StrictHostKeyChecking no
SSHEOF

chmod 600 ~/.ssh/config
echo ""
echo "✅ ~/.ssh/config 설정 완료!"
echo "이제 아래 명령어로 접속하세요:"
echo "  ssh bastion"
echo "  ssh k3s"
echo "  ssh monitoring"
