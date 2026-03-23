infra/terraform/
├── main.tf                 # [조립] 각 모듈을 호출하고 필요한 데이터(ID, IP)를 연결
├── providers.tf            # [설정] 모든 클라우드(AWS, GCP, CF)의 인증 정보를 한 곳에서 관리
├── variables.tf            # [공통 변수] 프로젝트 명, 리전 등 전역 변수 관리
└── modules/                # [부품] 실제 리소스를 정의하는 영역
    ├── network/            # VPC, Subnet 등 기본 네트워크 생성
    ├── aws/                # App 서버, Bastion 생성
    ├── gcp/                # GCP VM, Cloud SQL 생성
    └── monitoring/         # 모니터링 전용 EC2 및 SG 생성

필요 없다거나 의미가 없어진 파일은 삭제