infra/ansible/
├── ansible.cfg
├── inventory.ini #자동 생성 해야함
├── playbook.yml          # ← GCP, AWS 역할을 배분하는 메인 대본
├── group_vars/           # ← 서버 그룹별로 다른 변수 저장 --> 없어도 될듯?
alert_webhook_url: "{{ lookup('env', 'ALERT_WEBHOOK_URL') }}" # Discord Webhook URL
ebs_device_name: "/dev/xvdf"                                  # EBS 장치명 기본값
들어갈 내용
│   ├── all.yml           # 공통 변수 (프로젝트 명 등)
│   ├── gcp.yml           # GCP 전용 (DB 주소 등)
│   └── aws.yml           # AWS 전용 (AMI ID 등)
└── roles/
    ├── k3s_primary/      # GCP 전용 배역
    ├── k3s_standby/      # AWS(Worker) 전용 배역
    ├── node-exporter/    # 공통 배역
    └── monitoring/       # 모니터링 서버 전용 배역

playbook.yml
 # 1. 모든 서버 공통 작업
- hosts: all
  roles:
    - node-exporter
    - cloudflared

# 2. GCP 서버 (Primary K3s)
- hosts: gcp
  roles:
    - k3s_primary

# 3. AWS 서버 (Worker K3s + Monitoring)
- hosts: aws
  roles:
    - k3s
    - monitoring