OpenStack on Kubernetes
==============================================

처음 시작하는 분께
----------------------------

이 실습에서는 먼저 Linux 서버 안에 작은 서버 네 대(VM)를 만듭니다. 이 네 대를 하나의
Kubernetes 클러스터로 묶은 뒤, 그 위에 OpenStack을 설치합니다. 마지막에는 직접 이미지와
네트워크를 만들어 설치가 잘됐는지 확인합니다.

#. Windows PC에서는 VS Code의 PowerShell을 엽니다. 아래 한 줄의 주소를 팀에서 받은 SSH 주소로 바꾸세요.

   .. code-block:: powershell

      ssh lab@서버주소

#. 접속 후 ``hostname`` 과 ``whoami`` 를 실행하세요. 이제부터 ``bash`` 코드 블록은 이 Ubuntu 호스트에서
   실행합니다. ``yaml`` 과 ``ini`` 블록은 지정한 파일에 저장할 내용입니다.
#. **시작 전에 팀에서 받을 파일** — Terraform 설정·cloud-init 템플릿(1단계), Ansible 설정·플레이북(2단계),
   릴리스별 최종 Helm values 11개(5단계), 클라이언트 파드 매니페스트와 인증 설정(6단계)입니다.
   구축 기록에는 이 파일들의 전문이 없습니다. 팀 서버의 검증된 구성 파일을 사용해야 같은 구성을 따라갈 수 있습니다.
   인증 정보는 팀의 비공개 경로로 받으세요.
#. 문서에 표시된 경로는 호스트의 ``lab`` 계정 기준입니다. 명령은 블록별로 실행하고 예상 결과를 확인한 뒤 넘어가세요.
   실제 클러스터가 이미 운영 중이라면 새 실습 환경에서 시작하세요.

베어메탈 서버 한 대에서 VM 네 대를 만들고, 그 위에 Kubernetes와 OpenStack을 차례로 설치했습니다.
아래에는 팀이 직접 실행한 순서와 각 단계에서 확인한 결과를 정리했습니다.
처음 읽을 때는 개요에서 노드 구성을 본 뒤 0단계부터 읽으면 됩니다. 용어는 :doc:`용어집 <../glossary>` 에 모았습니다.

.. toctree::
   :maxdepth: 1

   overview
   ch0_prerequisites
   ch1_terraform_vm
   ch2_ansible
   ch3_kubernetes
   ch4_prereqs
   ch5_openstack
   ch6_verify
   ch7_troubleshooting
   appendix_versions
   appendix_manual_refs
   appendix_diagnostics

기존 주제별 안내
------------------------

.. toctree::
   :maxdepth: 1

   prerequisites
   infrastructure
   kubernetes