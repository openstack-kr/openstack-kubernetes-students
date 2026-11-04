.. _infrastructure:

==============================================
인프라 구성 (1~2단계: VM 생성과 노드 사전 설정)
===============================================
.. warning::

   **검토 필요**

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

.. code-block:: bash

   make stage-1

``stage1/apply.sh`` 는 사전 점검, 이미지·SSH 키 준비, AppArmor 설정을 거쳐
``stage1/terraform`` 에서 init, fmt 검사, validate, plan, apply를 실행합니다.
적용은 저장한 계획 파일을 사용하며 병렬도를 1로 제한합니다.
VM의 CPU 모드는 ``host-passthrough``, 머신 유형은 ``q35``, 아키텍처는
``x86_64`` 이며 디스크와 CD-ROM 부팅 순서를 지정합니다.
호스트 CPU 기능을 게스트에 노출하여 Calico의 x86-64-v2 호환성 문제에 대응하려는 설정입니다.
실제 호스트의 CPU 지원 여부와 설치 결과는 별도로 확인합니다.

Terraform 적용 후에는 네 VM의 상태를 확인합니다. 이미 실행 중이면 유지하고,
``shut off`` 상태이면 시작하며, 다른 상태이면 오류로 중단합니다.
그 뒤 인벤토리를 생성합니다.

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

1단계 사후 점검의 실제 풀 조회는 ``openinfra-lab`` 으로 수정되었습니다.
다만 출력 메시지에는 이전 이름이 남아 있습니다. 초기화 스크립트의 수동 정리 분기는
아직 다르므로 :doc:`troubleshooting` 을 참고하세요.

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

* `stage1/apply.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage1/apply.sh>`_
* `stage1/terraform/main.tf <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage1/terraform/main.tf>`_
* `stage1/postcheck.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage1/postcheck.sh>`_
* `common/generate-inventory.py <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/common/generate-inventory.py>`_
* `stage2/prepare-nodes.yml <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage2/prepare-nodes.yml>`_