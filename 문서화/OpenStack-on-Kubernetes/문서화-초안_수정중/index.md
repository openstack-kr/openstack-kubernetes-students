# OpenInfra Lab Kit 가이드북

OpenStack과 Kubernetes를 처음 구축해 보는 입문자를 위한 실습 가이드입니다.
빌린 서버 1대 안에 가상 머신(VM) 4대를 만들고, 그 위에 Kubernetes를, 다시 그 위에 OpenStack을 올리는 과정을
**처음부터 끝까지 따라 할 수 있게** 단계별로 설명합니다.

OpenInfra Lab Kit은 새로운 플랫폼이 아니라, 기존 오픈소스 도구를 **올바른 순서와 올바른 설정으로 엮고,
실패했을 때 어느 단계에서 왜 실패했는지 알아볼 수 있게** 해 주는 실습 지원 계층입니다.

> [!NOTE]
> 이 가이드는 **OpenStack on Kubernetes** 구조만 다룹니다. (Kubernetes on OpenStack은 설계만 했으며 향후 연구로 남겨 두었습니다.)
> 검증 범위는 서비스 동작(L2)까지이며, 사용자 VM(인스턴스) 생성은 범위 밖입니다.

> [!NOTE]
> 현재 문서는 **수동 구축**(공식 문서 절차를 직접 따라 하며 기록한 것)을 바탕으로 합니다.
> 0~4단계는 작성되어 있고, 5~6단계는 아직 구축하지 않았습니다.
> 각 장의 "키트로 실행하기"는 자동화 키트가 완성된 뒤에 채웁니다.

## 목차

1. [개요](overview.md): 무엇을 만드는가, 전체 흐름, 읽는 법
2. [0단계. 서버 확인과 도구 설치](ch0_prerequisites.md)
3. [1단계. VM 4대 만들기 (Terraform + libvirt)](ch1_terraform_vm.md)
4. [2단계. 노드 사전 설정 (Ansible)](ch2_ansible.md)
5. [3단계. Kubernetes 구축 (Kubespray)](ch3_kubernetes.md)
6. [4단계. 선행 요소 준비 (네트워크·스토리지)](ch4_prereqs.md)
7. [5단계. OpenStack 배포](ch5_openstack.md) (구축 전)
8. [6단계. 검증](ch6_verify.md) (구축 전)
9. [문제 해결](ch7_troubleshooting.md): 실제로 겪은 오류 모음
10. [부록 A. 버전 표](appendix_versions.md)
11. [부록 B. 수동 수행 기준 문서](appendix_manual_refs.md)
12. [부록 C. 용어집](appendix_glossary.md)
13. [부록 D. 진단 로그 수집과 새 머신 재현 검증](appendix_diagnostics.md)