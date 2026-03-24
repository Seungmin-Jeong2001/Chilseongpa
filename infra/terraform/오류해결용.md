앤서블 실행 중 생긴 오류 해결용




1. storage_setup_enabled 설정, 어떻게 할까?
이 설정은 **"운영체제가 설치된 기본 디스크 외에, 데이터를 저장할 별도의 '빈 디스크(EBS)'를 추가로 달았는가?"**에 따라 결정됩니다.

false로 설정해야 하는 경우 (추천)

따로 EBS 볼륨을 추가하지 않고, 그냥 서버 기본 용량(보통 8GB~20GB) 안에 도커와 DB를 다 때려 넣을 때.

연습용이거나 복잡한 마운트 과정 없이 빠르게 띄우고 싶을 때.

결과: /var/lib/prometheus 폴더를 만들긴 하지만, 별도 디스크 포맷/마운트 과정을 건너뜁니다.

true로 설정해야 하는 경우

테라폼에서 aws_ebs_volume을 만들고 aws_volume_attachment로 서버에 연결했을 때.

서버가 삭제되어도 프로메테우스의 데이터(로그, 메트릭)는 남기고 싶을 때.

결론: 현재 단계에서는 일단 **false**로 두고 앤서블을 돌리는 게 속 편합니다. 나중에 용량이 부족해지면 그때 디스크를 붙이고 true로 바꿔도 늦지 않아요.

2. AWS 인스턴스 타입과 장치명 확인법
앤서블이 실행 중인 상태에서 확인하거나, 직접 서버에 들어가서 확인하는 방법이 있습니다.

① 서버에 접속해서 직접 확인 (가장 확실함)
AWS 인스턴스 타입에 따라 디스크 장치명이 달라집니다. aws-monitor 서버에 SSH로 접속해서 아래 명령어를 쳐보세요.

Bash
# 1. 인스턴스 타입 확인
curl -s http://169.254.169.254/latest/meta-data/instance-type
# 결과 예: t2.micro, t3.small 등

# 2. 연결된 디스크 목록 확인
lsblk
② 인스턴스 타입별 장치명 규칙
t2 시리즈 (구형): 주로 /dev/sdb, /dev/sdc 등으로 잡힙니다.

t3 시리즈 이상 (신형/NVMe): /dev/nvme1n1, /dev/nvme2n1 식으로 잡힙니다.

🛠️ 적용 가이드 (all.yml 수정)
현재 에러를 해결하기 위해 group_vars/all.yml을 아래와 같이 업데이트하세요. 봇 관련 설정은 나중에 하더라도 변수 자리는 만들어 두는 게 에러 방지에 좋습니다.

YAML
# storage_setup_enabled를 false로 두면 아래 ebs_device_name은 무시됩니다.
storage_setup_enabled: false  
ebs_device_name: "/dev/xvdf" # 만약 나중에 장치명이 확인되면 수정

# 모니터링 기본 디렉토리
monitoring_base_dir: "/home/{{ ansible_user }}/monitoring"

# 렌더링 모드 설정 (에러 방지용)
config_render_mode: "template"
prometheus_config_src: "prometheus.yml.j2"
alertmanager_config_src: "alertmanager.yml.j2"
alert_rules_src: "alert.rules.yml.j2"
grafana_datasource_src: "datasource.yml.j2"
grafana_dashboard_provider_src: "dashboard.yml.j2"

# 디스코드 관련 (나중을 위해 일단 빈값이나 환경변수 처리)
discord_bot_token: "{{ lookup('env', 'DISCORD_BOT_TOKEN') | default('dummy') }}"
gemini_api_key: "{{ lookup('env', 'GEMINI_API_KEY') | default('dummy') }}"
✅ 이제 이렇게 해보세요
**group_vars/all.yml**에 위 변수들을 복사해 넣는다. (특히 storage_setup_enabled: false)

**ansible-playbook playbook.yml**을 다시 실행한다.

이렇게 하면 아까 멈췄던 Create Prometheus data dir 단계를 가볍게 넘어가고, 도커 위에 모니터링 스택이 올라가기 시작할 겁니다.

"변수 업데이트 후에 플레이북을 다시 돌려보시겠어요? 설치가 끝나면 브라우저에서 그라파나 로그인이 되는지 바로 확인해 봅시다!"