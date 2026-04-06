#!/bin/bash
# SSH 설정 자동화 스크립트
# terraform apply 이후 IP가 바뀔 때마다 실행하면 됩니다
# 사용법: bash infra/setup-ssh.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="${SCRIPT_DIR}/terraform"
KEY_DIR="${SCRIPT_DIR}/.."
SSH_CONFIG="${HOME}/.ssh/config"

cd "$TF_DIR"

echo "📡 Terraform output 읽는 중..."
GCP_MON_IP=$(terraform output -raw gcp_monitoring_ephemeral_ip 2>/dev/null || echo "")
GCP_K3S_IP=$(terraform output -raw gcp_k3s_ephemeral_ip 2>/dev/null || echo "")
AWS_K3S_IP=$(terraform output -raw aws_k3s_public_ip 2>/dev/null || echo "")

if [ -z "$GCP_MON_IP" ] || [ -z "$AWS_K3S_IP" ]; then
  echo "❌ terraform output을 읽을 수 없습니다. terraform apply를 먼저 실행하세요."
  exit 1
fi

MARKER_START="# === CHILSEONGPA START ==="
MARKER_END="# === CHILSEONGPA END ==="

# ~/.ssh/config 없으면 생성
mkdir -p "${HOME}/.ssh"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

# 기존 설정 제거
if grep -q "$MARKER_START" "$SSH_CONFIG" 2>/dev/null; then
  sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$SSH_CONFIG"
fi

# 새 설정 추가
cat >> "$SSH_CONFIG" << EOF

$MARKER_START
Host gcp-monitoring
  HostName ${GCP_MON_IP}
  User ubuntu
  IdentityFile ${KEY_DIR}/my_gcp_key
  StrictHostKeyChecking no

Host gcp-k3s
  HostName ${GCP_K3S_IP}
  User ubuntu
  IdentityFile ${KEY_DIR}/my_gcp_key
  StrictHostKeyChecking no

Host aws-k3s
  HostName ${AWS_K3S_IP}
  User ubuntu
  IdentityFile ${KEY_DIR}/chilseongpa_keypair.pem
  StrictHostKeyChecking no
$MARKER_END
EOF

echo ""
echo "✅ SSH 설정 완료!"
echo ""
echo "접속 방법:"
echo "  ssh gcp-monitoring   # GCP 모니터링 VM (Prometheus, Grafana)"
echo "  ssh gcp-k3s          # GCP K3s Primary 노드"
echo "  ssh aws-k3s          # AWS K3s Standby 노드 (직접 접속)"
