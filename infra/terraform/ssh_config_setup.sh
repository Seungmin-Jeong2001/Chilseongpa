#!/bin/bash
# -----------------------------------------------
# terraform apply 후 ~/.ssh/config 자동 생성
# 실행: bash ssh_config_setup.sh
# -----------------------------------------------

K3S_IP=$(terraform output -raw aws_k3s_public_ip)
KEY=../../chilseongpa_keypair.pem

echo "AWS k3s IP  : $K3S_IP"

# 기존 설정 제거 (k3s 관련)
sed -i.bak '/Host aws-k3s-direct/,/StrictHostKeyChecking no/d' ~/.ssh/config 2>/dev/null

cat >> ~/.ssh/config << SSHEOF

# -----------------------------------------------
# Chilseongpa AWS (Public Direct Access)
# -----------------------------------------------
Host aws-k3s-direct
  HostName $K3S_IP
  User ubuntu
  IdentityFile $KEY
  StrictHostKeyChecking no
SSHEOF

chmod 600 ~/.ssh/config
echo ""
echo "✅ ~/.ssh/config 설정 완료!"
echo "이제 아래 명령어로 접속하세요:"
echo "  ssh aws-k3s-direct"
