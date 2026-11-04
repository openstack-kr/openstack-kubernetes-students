.. _prerequisites:

========================================
사전 준비 (0단계: 환경 점검과 도구 설치)
========================================

목표는 호스트의 구축 조건을 확인하고 지정한 도구를 설치하는 것입니다.

실행 환경과 요구 조건
------------------------------------------------------------------------------------------

구현의 사전 검사는 베어메탈, Ubuntu 24.04, ``/dev/kvm``, Intel ``vmx`` 플래그,
CPU 40스레드 이상, 총 메모리 112GiB 이상, 루트 파일시스템 여유 공간 340GiB 이상을
검사합니다. AMD 가상화 플래그는 현재 검사에 포함되지 않습니다.

VM 메모리 할당 합계가 112GiB이므로 검사 최솟값만 맞춘 서버에는 호스트 여유 메모리가
부족할 수 있습니다. 호스트 운영에 필요한 자원을 별도로 남겨 두어야 합니다.
1단계는 디스크 공간을 ``/var/lib/libvirt`` 기준으로 다시 검사합니다.

``sudo -n true`` 가 성공해야 하며, 일반 계정으로 실행합니다.
시간 동기화와 외부 다운로드 경로 접근이 필요합니다. 현재 0단계의 네트워크 검사는
``github.com`` 이름 해석이므로 모든 다운로드 서버나 UDP 123 접근을 검사하는 것은 아닙니다.

저장소 준비와 실행
------------------------------------------------------------------------------------------

Ubuntu 호스트에 ``git`` 과 ``make`` 가 있어야 합니다.

.. code-block:: bash

   git clone https://github.com/mayura13/openstack_project.git
   cd openstack_project
   git rev-parse HEAD
   make stage-0

최신 커밋이 이 문서의 기준과 다르면 변경된 스크립트를 대조합니다.
단계를 나누어 실행할 때는 아래 순서를 사용합니다.

.. code-block:: bash

   make preflight
   make install
   make postcheck

``make install`` 만으로 사전·사후 점검까지 실행되는 것은 아닙니다.
설치 도중 ``libvirt`` 와 ``kvm`` 그룹을 추가하면 스크립트가 종료 코드 2로 멈춥니다.
안내에 따라 로그아웃 후 다시 로그인하고 설치와 점검을 다시 실행합니다.

설치 결과
------------------------------------------------------------------------------------------

호스트에 libvirt/KVM 관련 패키지와 Terraform, kubectl, Helm을 설치합니다.
Kubespray는 ``~/kubespray``, Ansible 환경은 ``~/venv-kubespray``,
OpenStack CLI 환경은 ``~/venv-openstack`` 에 준비합니다.
버전이 다른 바이너리를 교체할 수 있으며, 기존 Kubespray 커밋이 다르면 중단합니다.

.. code-block:: bash

   terraform version
   kubectl version --client
   helm version --short
   ~/venv-kubespray/bin/ansible --version
   ~/venv-openstack/bin/openstack --version
   virsh list --all
   timedatectl show -p NTPSynchronized --value

설치 후 검사는 버전, 권한, libvirt 동작, 시간 동기화와 잔여 VM 유무를 확인합니다.
이미 VM이 있으면 실패할 수 있으므로 완성된 환경에서 전체 배포를 반복 실행하는
방식으로 사용하지 않습니다. 다음 단계는 :doc:`infrastructure` 입니다.

.. _prerequisites-ntp:

시간 동기화 실패
------------------------------------------------------------------------------------------

``timedatectl`` 로 실제 동기화 여부를 확인하고 사용하는 시간 서비스의 상태와 로그를
확인합니다. chrony가 설치된 환경은 ``chronyc sources`` 도 사용할 수 있습니다.
이름 해석 성공만으로 NTP 통신 성공을 판단하지 않습니다.


구현 근거
------------------------------------------------------------------------------------------

* `stage0/preflight.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage0/preflight.sh>`_
* `stage0/install.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage0/install.sh>`_
* `stage0/postcheck.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage0/postcheck.sh>`_

====================================================================================================
대상 파일: doc/source/openstack-on-kubernetes/kit/infrastructure.rst
아래부터 파일 전체 내용
====================================================================================================

.. _infrastructure:

인프라 구성 (1~2단계: VM 생성과 노드 사전 설정)
==========================================================================================

0단계 점검 후 VM을 생성하고 Ansible이 노드 내부를 준비합니다.

노드와 네트워크
------------------------------------------------------------------------------------------

.. list-table:: Terraform 할당값
   :header-rows: 1

   * - 노드
     - IP
     - vCPU
     - 메모리 GiB
     - 디스크 GiB
   * - cp
     - 192.168.100.10
     - 4
     - 16
     - 60
   * - ctrl-worker
     - 192.168.100.11
     - 16
     - 32
     - 120
   * - compute-1
     - 192.168.100.21
     - 10
     - 32
     - 80
   * - compute-2
     - 192.168.100.22
     - 10
     - 32
     - 80

합계는 40 vCPU, 메모리 112GiB, 가상 디스크 340GiB입니다.
실제 파일 사용량과 게스트에서 표시하는 용량은 할당값과 다를 수 있습니다.
NAT 네트워크는 ``openinfra-lab``, 대역은 ``192.168.100.0/24`` 입니다.
스토리지 풀 이름도 ``openinfra-lab`` 이며 경로는 ``/var/lib/libvirt/images`` 입니다.
Terraform 리소스 식별자 ``libvirt_pool.openinfra`` 의 ``openinfra`` 는 실제 풀 이름이 아닙니다.

1단계 실행
------------------------------------------------------------------------------------------

.. warning::

   기준 커밋의 사후 점검은 풀 이름을 ``openinfra`` 로 조회합니다.
   생성 코드와 일치하지 않아 정상 생성 후에도 실패할 수 있습니다.
   :doc:`troubleshooting` 의 불일치를 구현 담당자와 먼저 수정·확인하세요.

.. code-block:: bash

   make stage-1

``stage1/apply.sh`` 는 사전 점검, 이미지·SSH 키 준비, AppArmor 설정을 거쳐
``stage1/terraform`` 에서 init, fmt 검사, validate, plan, apply를 실행합니다.
적용은 저장한 계획 파일을 사용하며 병렬도를 1로 제한합니다.

Ubuntu noble 이미지 릴리스 ``20261017`` 을 다운로드하고 스크립트의 SHA256과 비교합니다.
cloud-init은 ``kit`` 계정, SSH 키, 호스트명을 설정합니다.
키 경로는 ``~/.ssh/id_vm_ed25519`` 입니다.
AppArmor 스크립트는 local abstraction에 디스크 경로 허용 규칙을 추가하고
프로파일을 다시 읽습니다. AppArmor 전체를 끄는 절차는 아닙니다.

Terraform 출력으로 ``stage2/inventory.ini`` 와 ``stage3/inventory/inventory.ini`` 를
생성합니다. 생성 파일을 직접 수정하면 다음 생성 때 덮어써질 수 있습니다.

.. code-block:: bash

   virsh list --all
   virsh net-info openinfra-lab
   virsh pool-info openinfra-lab
   ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 hostname

2단계 실행
------------------------------------------------------------------------------------------

.. code-block:: bash

   make stage-2

``stage2/prepare-nodes.yml`` 은 swap 비활성화와 fstab 수정, overlay와 br_netfilter
모듈, 커널 네트워크 설정, hosts 파일과 cloud-init hosts 템플릿, 필수 패키지를
설정합니다. 호스트명 생성은 앞 단계의 cloud-init이 담당합니다.

DNS 검색 도메인 전달을 제어하기 위해 Netplan의
``/etc/netplan/90-openinfra-dns.yaml`` 에 ``use-domains: false`` 를 설정합니다.
현재 인터페이스 이름은 ``enp1s0`` 로 고정되어 있으므로 다른 환경은 실제 이름과
비교해야 합니다. 설정 파일만 작성하고 끝나는 것이 아니라 변경 시 Netplan을 적용합니다.

점검을 통과하면 :doc:`kubernetes` 로 이동합니다.


구현 근거
------------------------------------------------------------------------------------------

* `stage1/apply.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage1/apply.sh>`_
* `stage1/terraform/main.tf <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage1/terraform/main.tf>`_
* `stage1/postcheck.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage1/postcheck.sh>`_
* `common/generate-inventory.py <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/common/generate-inventory.py>`_
* `stage2/prepare-nodes.yml <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage2/prepare-nodes.yml>`_