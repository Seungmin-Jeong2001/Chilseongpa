## 변경 사항
<!-- 이 PR에서 변경한 내용을 간략히 설명해주세요 (예시 삭제 후 작성) -->

예시
- Prometheus 모니터링 추가
- Terraform VPC 구성
- Discord Bot 알림 기능 구현

---

## 담당 영역 (Scope)

해당되는 영역 체크

- [ ] Infrastructure
- [ ] Terraform
- [ ] Ansible
- [ ] Kubernetes (k3s)
- [ ] Backend
- [ ] Monitoring / Observability
- [ ] AIOps Bot
- [ ] CI/CD
- [ ] Documentation

---

## 변경 유형

- [ ] 버그 수정 (fix)
- [ ] 새 기능 추가 (feat)
- [ ] 리팩토링 (refactor)
- [ ] 인프라 / 설정 변경 (infra)
- [ ] 성능 개선 (perf)
- [ ] 문서 업데이트 (docs)

---

## 기능 검증

- [ ] 로컬 환경에서 정상 동작을 확인했습니다
- [ ] 기존 기능에 영향이 없는지 확인했습니다
- [ ] 오류 발생 가능성을 점검했습니다

---

## 인프라 변경 (Terraform / Ansible)
해당되는 경우만 체크

- [ ] `terraform plan` 결과를 확인했습니다
- [ ] Ansible playbook 실행 테스트를 완료했습니다
- [ ] 기존 인프라에 영향이 없는지 확인했습니다

---

## Kubernetes 변경

해당되는 경우만 체크

- [ ] Deployment 변경
- [ ] Service 변경
- [ ] Ingress 변경
- [ ] ConfigMap / Secret 변경

---

## 보안 체크리스트

- [ ] API Key / Secret / Token 등 민감 정보가 코드에 포함되지 않았습니다
- [ ] 민감 정보가 로그에 출력되지 않습니다
- [ ] 사용자 입력값 검증이 적용되었습니다

---

## Git 규칙 확인

- [ ] `main` 브랜치가 아닌 `feature` 브랜치에서 작업했습니다
- [ ] 불필요한 파일(.env, build, node_modules 등)이 포함되지 않았습니다

---

## 인프라 영향도

- [ ] 새로운 환경변수가 필요합니다 → 변수명:
- [ ] 데이터베이스 스키마 변경이 있습니다
- [ ] 새로운 포트 / 엔드포인트가 추가됩니다
- [ ] 리소스(CPU / Memory) 요구사항이 변경됩니다
- [ ] 기존 서비스에 영향 없습니다

---

## Observability 영향

- [ ] Prometheus Metric 추가
- [ ] Grafana Dashboard 변경
- [ ] Alert Rule 추가 / 변경

---

## 테스트

- [ ] 단위 테스트 추가 / 수정
- [ ] 통합 테스트 추가 / 수정
- [ ] 수동 테스트 완료

---

## 관련 이슈

Closes #