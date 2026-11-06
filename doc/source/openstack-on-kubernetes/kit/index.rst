lab kit 가이드북
==========================================================================================

이 장을 읽기 전에
------------------------------------------------------------------------------------------

자동화 키트는 여러 설치 명령을 단계별로 묶어 실행하는 도구 모음입니다.
``make stage-0`` 처럼 단계 이름을 지정하면 해당 작업을 실행합니다.
각 단계가 끝나면 결과를 확인한 뒤 다음 단계로 진행합니다.

이 가이드의 명령은 SSH로 접속한 Ubuntu 호스트의
``openstack_project`` 폴더에서 실행합니다.
이 폴더는 ``Makefile`` 과 ``stage0`` 등의 폴더가 있는 위치입니다.

실행 전에 다음 명령으로 서버 이름, 로그인 계정과 현재 폴더를 확인합니다.

.. code-block:: bash

   hostname
   whoami
   pwd

낯선 용어는 :doc:`/glossary` 를 참고하세요.

.. note::

   이 가이드는 자동화 코드의 실행 방법을 설명합니다.
   새 서버에서의 전체 구축 성공 여부는 실제 실행 결과로 확인해야 합니다.
   환경 초기화 전에는 :doc:`troubleshooting` 의 주의사항을 확인하세요.

이 가이드에서 하는 일
------------------------------------------------------------------------------------------

베어메탈 호스트에 도구를 설치하고, 노드 VM 네 대를 생성한 뒤 Kubernetes와
OpenStack을 배포합니다. 서비스 API 검증과 상태 수집은 6단계에서 실행하며 전체 배포에도 포함됩니다.
``make`` 는 Makefile에 적힌 명령 묶음을 실행하는 도구입니다. 각 대상 이름은
구현 저장소가 정한 것이므로 다른 프로젝트에 그대로 적용할 수는 없습니다.
과거 수동 작업과 결과는 :doc:`../manual/index` 에서 읽습니다.

대상 독자
------------------------------------------------------------------------------------------

Linux 명령과 SSH 접속을 사용하며 OpenStack과 Kubernetes 구축 과정을 익히려는
실습자를 대상으로 합니다. 도구의 역할은 :doc:`/foundations/lab-kit-tools` 를 참고하세요.

구축 구조
------------------------------------------------------------------------------------------

.. code-block:: text

   Ubuntu 호스트
     └─ libvirt / QEMU / KVM
         ├─ cp            : Kubernetes 컨트롤 플레인과 etcd
         ├─ ctrl-worker   : OpenStack 제어 서비스
         ├─ compute-1     : OpenStack 컴퓨트 서비스
         └─ compute-2     : OpenStack 컴퓨트 서비스

.. list-table:: 실행 순서
   :header-rows: 1

   * - 단계
     - 명령
     - 작업
   * - 0
     - ``make stage-0``
     - 호스트 사전 점검 → 도구 설치 → 설치 후 점검
   * - 1
     - ``make stage-1``
     - VM 생성과 인벤토리 생성, 결과 점검
   * - 2
     - ``make stage-2``
     - Ansible로 VM 내부 설정
   * - 3
     - ``make stage-3``
     - Kubespray로 Kubernetes 설치
   * - 4
     - ``make stage-4``
     - 노드 라벨, 저장소, Helm 배포 준비
   * - 5
     - ``make stage-5``
     - Horizon을 포함한 Helm 릴리스 12개 배포와 점검
   * - 6
     - ``make stage-6``
     - 서비스 검증과 최종 상태 수집

``make deploy`` 는 0~6단계를 실행하며 마지막에 서비스 검증과 상태 수집을 수행합니다.
``make -j`` 로 병렬 실행하지 않습니다.
``bash run-deploy.sh run-01`` 은 전체 실행 출력과 시간을 ``logs/run-01`` 에 기록합니다.
이미 같은 실행 번호의 폴더가 있으면 중단하므로 새 번호를 사용합니다.
다만 Makefile의 6단계 결과 경로는 ``logs/evaluation`` 으로 고정되어 있어 실행 번호별로
자동 분리되지 않습니다. 회차별 보관 방법은 :doc:`verification` 을 참고하세요.
``make up``, ``make verify``, ``make destroy`` 는 이 가이드에서 사용하는
실행 명령에 포함되지 않습니다.

기준 버전
------------------------------------------------------------------------------------------

다음은 코드에 지정된 값입니다. 모든 버전이 하나의 파일에서 관리되는 것은 아닙니다.

.. list-table:: 버전과 설정 위치
   :header-rows: 1

   * - 항목
     - 값
     - 위치
   * - Terraform / libvirt provider
     - 1.15.9 / 0.9.9
     - ``versions.env``, ``stage1/terraform/versions.tf``
   * - kubectl / Helm
     - 1.35.4 / 3.18.4
     - ``versions.env``
   * - ansible-core / OpenStack CLI
     - 2.18.19 / 10.5.0
     - ``versions.env``
   * - Kubespray
     - v2.31.0, 짧은 커밋 ID ``1c9add4``
     - ``versions.env`` 와 단계별 검사
   * - Kubernetes
     - 1.35.4
   * -
     - Kubespray
     - v2.31.0 (커밋 ``1c9add4``)
   * -
     - 네트워크 플러그인
     - Calico (Kubespray 기본값)
   * -
     - 컨테이너 런타임
     - containerd 2.2.3
   * - 구축 도구
     - Terraform
     - 1.15.9
   * -
     - libvirt provider (dmacvicar/libvirt)
     - 0.9.9
   * -
     - ansible-core
     - 2.18.20
   * -
     - Helm
     - v3.18.4
   * -
     - kubectl
     - v1.35.4
   * -
     - openstack CLI
     - 10.5.0
   * - OS
     - 호스트 서버
     - Ubuntu 24.04.1, 커널 6.8.0-51
   * -
     - 노드 VM
     - Ubuntu 24.04.5, 커널 6.8.0-147 (cloud image 릴리스 20261017)

.. note::
   호스트와 노드 VM 은 Ubuntu 24.04 이지만 세부 버전이 다릅니다. OpenStack
   차트의 세부 버전은 :doc:`openstack-deploy` 장의 표를 참고하세요.

수동 구축 때 확인한 호스트·노드 운영체제와 런타임 버전은
:doc:`../manual/appendix_versions` 에 별도로 기록되어 있습니다.
자동화 코드의 고정값과 특정 서버에서 측정한 버전을 구분해서 확인합니다.

범위와 한계
------------------------------------------------------------------------------------------

* 단일 물리 호스트 실습입니다. 호스트 장애를 견디는 구성이 아닙니다.
* 노드 VM 생성에는 호스트 KVM을 사용하지만, Nova 사용자 VM 설정은 ``qemu`` 입니다.
* 저장소는 노드 로컬 디스크를 사용하는 local-path입니다. 복제 스토리지가 아닙니다.
* 검증 스크립트는 사용자 인스턴스를 부팅하거나 Floating IP 통신을 시험하지 않습니다.
* Horizon 배포 및 Pod 점검은 웹 로그인과 인스턴스 생성 성공을 보장하지 않습니다.
* 깨끗한 환경의 반복 구축, 재부팅 이후 동작은 별도의 실행 기록으로 입증해야 합니다.

이 가이드를 읽는 방법
------------------------------------------------------------------------------------------

사전 준비부터 순서대로 읽고, 단계별 점검을 통과한 뒤 다음 단계로 이동합니다.
실패한 환경에서 전체 배포를 다시 실행하면 기존 VM 검사에 막힐 수 있습니다.
재실행 전 현재 자원과 실패 위치를 확인하세요.

.. toctree::
   :maxdepth: 2

   prerequisites
   infrastructure
   kubernetes
   prereq-components
   openstack-deploy
   verification
   troubleshooting


참고 코드
------------------------------------------------------------------------------------------

* `Makefile <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/Makefile>`_
* `run-deploy.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/run-deploy.sh>`_
* `versions.env <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/versions.env>`_
