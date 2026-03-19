# Ansible — AWS Standby

AWS Standby 환경의 서버 설정을 Ansible로 자동화한다.

---

## 파일 역할

| 파일/폴더 | 역할 |
|---|---|
| `ansible.cfg` | Ansible 기본 설정 |
| `playbook.yml` | 전체 role 실행 순서 정의 |
| `inventory.ini` | 배포 대상 서버 목록 (terraform apply 시 자동 생성) |
| `roles/k3s/` | k3s 설치 + kubeconfig 설정 |
| `roles/node-exporter/` | Prometheus 메트릭 수집 서비스 |
| `roles/cloudflared/` | Cloudflare Tunnel Pod 배포 |

---

## 실행 순서

```
playbook.yml
  ├── k3s role          # k3s 설치 + Ready 확인
  ├── node-exporter role # Node Exporter 설치 + :9100 확인
  └── cloudflared role  # tunnel_token 있을 때만 실행
```

---

## 각 Role 설명

### k3s

k3s를 설치하고 클러스터가 Ready 상태가 될 때까지 대기한다. 완료 후 kubeconfig를 로컬로 가져오고 서버 주소를 EC2 Public IP로 치환한다.

```
k3s 설치
  ↓
k3s 서비스 시작
  ↓
Node Ready 확인
  ↓
kubeconfig 로컬 저장 (kubeconfig/k3s.yaml)
```

### node-exporter

Prometheus가 인프라 메트릭을 수집할 수 있도록 Node Exporter를 설치하고 systemd 서비스로 등록한다.

- 버전: v1.7.0
- 포트: `:9100`
- 희정님 Prometheus가 이 포트로 scrape

### cloudflared

Cloudflare Tunnel을 k3s Deployment로 배포한다. `tunnel_token`이 없으면 자동으로 건너뛴다.

```yaml
# tunnel_token이 있을 때만 실행
when: tunnel_token is defined and tunnel_token | trim != ""
```

tunnel_token은 승민님한테 받아서 실행 시 전달:

```bash
ansible-playbook -i inventory.ini playbook.yml \
  -e "tunnel_token=<CF_TUNNEL_TOKEN>"
```

---

## 로컬 실행

```bash
# inventory.ini에 k3s 노드 IP 입력
echo "[aws_standby]" > inventory.ini
echo "<k3s_public_ip> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/<key>.pem" >> inventory.ini

# tunnel_token 없이 실행 (cloudflared 건너뜀)
ansible-playbook -i inventory.ini playbook.yml \
  --private-key ~/.ssh/<key>.pem

# tunnel_token 포함 실행
ansible-playbook -i inventory.ini playbook.yml \
  --private-key ~/.ssh/<key>.pem \
  -e "tunnel_token=<CF_TUNNEL_TOKEN>"
```

---

## Tunnel 연결 확인

cloudflared 배포 완료 후 Cloudflare 대시보드에서 확인:

```
Cloudflare 대시보드 → Zero Trust → Networks → Tunnels
→ chilseong-tunnel-aws 상태가 HEALTHY인지 확인
```
