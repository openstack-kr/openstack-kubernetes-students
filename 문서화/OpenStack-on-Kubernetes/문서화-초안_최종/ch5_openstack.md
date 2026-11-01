# 5단계. OpenStack 배포 (구축 전)

## 이 장에서 하는 일

OpenStack-Helm으로 다음 서비스를 배포합니다.

- 의존 서비스: MariaDB, RabbitMQ, Memcached
- Keystone, Glance, Neutron, Nova, Placement

## 선행 조건

- 4단계 완료

## 키트로 실행하기

```bash
make stage-5
```

## 단계별로 따라 하기

### values 오버라이드

ctrl-worker(메모리 제한)에 맞춰 MariaDB, RabbitMQ 등의 replica 수와 리소스 요청을 낮춘 설정을 사용합니다.

> [!NOTE]
> **TODO:** `openstack-helm/` 의 values 파일 목록과 변경 항목, 변경 이유

### 이미지 태그 고정

`latest` 태그는 사용하지 않고 모든 이미지를 태그 또는 다이제스트로 고정합니다.

> [!NOTE]
> **TODO:** 고정 방식과 위치 (`versions.env`)

### Nova virt_type

노드가 VM이므로 `qemu` 를 사용합니다. (L2 검증에서는 사용자 VM을 띄우지 않으므로 충분)

### 배포 순서

> [!NOTE]
> **TODO:** 서비스별 배포 순서와 의존 관계

## 기대 결과 / 확인 방법

> [!NOTE]
> **TODO:** Helm 릴리스 목록, Pod 상태 출력 예시

## 막혔을 때

[문제 해결](ch7_troubleshooting.md) 의 "5단계" 항목을 참고하세요.
