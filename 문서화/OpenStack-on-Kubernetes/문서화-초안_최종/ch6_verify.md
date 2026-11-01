# 6단계. 검증 (구축 전)

## 이 장에서 하는 일

배포 결과와 서비스 동작을 확인합니다. 각 항목은 O/X로 판정되며, 실패 시 어느 단계의 어떤 항목인지 출력됩니다.
검증 수준은 L2(서비스 동작, 서비스 간 연동)까지이고 사용자 VM 생성은 포함하지 않습니다.

## 키트로 실행하기

```bash
make verify     # 또는 make stage-6
```

## 배포 검증

| 항목 | 기준 |
|---|---|
| Pod 상태 | 모두 `Running` 또는 `Completed`. `Running` 은 Ready 상태 |
| Helm 릴리스 | 모두 `deployed` |

> [!NOTE]
> `Completed` 를 허용하는 이유: OpenStack-Helm의 초기화용 Job Pod가
> 정상 상태에서도 Completed로 남습니다.

## 서비스 동작 검증

| 서비스 | 확인 항목 |
|---|---|
| Keystone | 토큰 발급 성공 |
| Glance | 이미지 등록 성공 (작은 테스트 이미지) |
| Neutron | 네트워크 생성 성공, 에이전트 상태 정상 |
| Nova | nova-compute 2대 모두 up, 하이퍼바이저 목록 확인 |
| Placement | 리소스 제공자 2개 확인 |

서비스 간 연동(Nova → Placement, Nova → Neutron, 각 서비스 → Keystone 인증)도 함께 확인합니다.

## 기대 결과

> [!NOTE]
> **TODO:** 전체 통과 시 O/X 출력, 실패 시 출력 예시

## 막혔을 때

[문제 해결](ch7_troubleshooting.md) 의 "6단계" 항목을 참고하세요.
