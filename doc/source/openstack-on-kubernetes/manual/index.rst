========
수동구축
========

베어메탈 서버 한 대에 노드 VM 4대를 만들고, 그 위에 Kubernetes 와 OpenStack 을
**손으로 직접 구축하며 남긴 기록**\ 입니다. 어떤 명령을 어떤 순서로 실행했고, 어디서
막혔으며, 어떻게 해결했는지를 단계별로 정리했습니다.

자동화 키트로 같은 구조를 구축하는 방법은 :doc:`../kit/index` 를 참고하세요.

.. list-table:: 이 기록과 키트 가이드의 차이
   :header-rows: 1
   :widths: 20 40 40

   * - 구분
     - 수동 구축 (이 장)
     - 키트 가이드
   * - 목적
     - 구축 과정과 시행착오의 기록
     - 키트를 사용해 같은 환경을 재현
   * - 실행 방식
     - 명령을 직접 입력
     - ``make`` 명령으로 단계 실행
   * - 중점
     - 왜 그렇게 했는지, 무엇이 실패했는지
     - 어떻게 실행하고 무엇을 확인하는지

구축 순서
=========

각 장은 구축 단계와 같은 번호를 씁니다.

.. code-block:: text

   [0 사전 준비] → [1 Terraform+libvirt] → [2 Ansible] → [3 Kubespray]
     → [4 선행 요소] → [5 OpenStack-Helm] → [6 검증] → [7 문제 해결]

.. toctree::
   :maxdepth: 1
   :caption: 단계별 기록
   
   overview
   ch0_prerequisites
   ch1_terraform_vm
   ch2_ansible
   ch3_kubernetes
   ch4_prereqs
   ch5_openstack
   ch6_verify
   ch7_troubleshooting

.. toctree::
   :maxdepth: 1
   :caption: 부록

   appendix_versions
   appendix_diagnostics
   appendix_manual_refs