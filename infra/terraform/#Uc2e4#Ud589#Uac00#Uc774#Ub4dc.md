



🚀 실행 및 확인 방법
배포: terraform apply -auto-approve 실행.

확인: infra/ansible/inventory.ini 파일을 열어 IP 주소가 실제 값으로 바뀌어 있는지 확인.

테스트: cd ../ansible 이동 후 ansible all -m ping 명령어로 모든 서버와 통신이 되는지 확인.


ansible all -m ping

# 베스천(AWS 대문) 확인
ansible aws_bastion -m ping

# AWS 내부망 서버 확인 (베스천 터널링 작동 여부 체크)
ansible aws_nodes -m ping

# GCP 서버 확인
ansible gcp_primary -m ping