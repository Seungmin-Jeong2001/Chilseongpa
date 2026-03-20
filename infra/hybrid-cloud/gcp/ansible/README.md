---

앤서블 설명서


# Ansible — GCP Primary

Terraform으로 생성된 GCP 인프라 위에 K3s를 설치하고, 외부 통신을 위한 Cloudflare Tunnel 파드를 배포합니다.

## 📂 파일 역할
| 파일명/폴더 | 역할 |
|---|---|
| `ansible.cfg` | Ansible 기본 설정 |
| `site.yml` | 전체 Role 실행 순서 정의 (Playbook) |
| `roles/` | K3s 설치 및 `cloudflared` 에이전트 배포 로직 |

## 🔄 Cloudflare Tunnel 방식
K3s 내부에 배포된 `cloudflared` 파드가 외부(Cloudflare)로 먼저 아웃바운드 연결을 맺어 터널을 생성합니다. 인바운드 방화벽 개방 없이 안전하게 트래픽을 라우팅합니다.

## 🚀 실행 가이드
Terraform 배포가 완료된 후, Tunnel Token을 주입하여 실행합니다.

```bash
cd ansible
# inventory.ini에 GCP VM IP가 등록된 상태에서 실행
ansible-playbook -i inventory.ini site.yml -e "cloudflare_token=<CF_TUNNEL_TOKEN>"
```

GCP는 k3s_primary role 내에 node-exporter 설치가 포함되어 있습니다

