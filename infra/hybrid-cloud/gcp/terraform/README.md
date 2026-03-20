# Terraform — GCP Primary

GCP Primary 환경의 네트워크, 보안, 컴퓨팅 리소스를 코드로 프로비저닝합니다.

## 🛠️ 사전 준비 (Prerequisites)
Terraform 실행 전, GCP 프로젝트에 필요한 API들을 활성화해야 합니다. (Terraform 실행 시 API 활성화 지연으로 인한 Dependency 에러를 원천 차단하기 위함입니다.)
아래 명령어를 터미널에서 1회 실행해 주세요.

```bash
gcloud services enable compute.googleapis.com \
                       secretmanager.googleapis.com \
                       sqladmin.googleapis.com
```

📂 파일 역할파일명역할

main.tf	          Terraform 설정 및 GCP Provider 구성

network.tf	      VPC 및 Subnet 구성

compute.tf	      K3s를 구동할 Compute Engine (VM) 생성

database.tf	      백엔드 데이터베이스 리소스 생성

security.tf	      Zero Trust 방화벽 규칙 (22번 포트만 개방)

variables.tf	    프로젝트 ID, DB 비밀번호 등 변수 정의

outputs.tf	      배포 완료 후 접근용 IP 등 결과값 출력
