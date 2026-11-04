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

* `stage0/preflight.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage0/preflight.sh>`_
* `stage0/install.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage0/install.sh>`_
* `stage0/postcheck.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage0/postcheck.sh>`_
