=======================
OpenStack on Kubernetes Kit 가이드
=======================

OpenStack 의 각 서비스(Keystone, Glance, Neutron, Nova, Placement 등)를
컨테이너로 패키징해 Kubernetes 위에서 운영하는 방식입니다.
이 가이드는 베어메탈 서버 한 대에서 가상 노드 4대를 만들고, 그 위에
Kubernetes 와 OpenStack 을 순서대로 구축하는 과정을 설명합니다.

이 가이드에서 하는 일
=====================

* 서버 환경을 점검하고 필요한 도구를 설치합니다.
* libvirt/KVM 위에 노드 VM 4대를 만듭니다.
* Kubespray 로 Kubernetes 클러스터를 구축합니다.
* OpenStack-Helm 으로 OpenStack 핵심 서비스를 배포합니다.
* 배포 상태와 서비스 간 연동을 확인합니다.

대상 독자
=========

OpenStack 과 Kubernetes 를 처음 접하며, 한 대의 서버에서 직접 구축해
보고 싶은 입문자를 대상으로 합니다. Linux 터미널 사용에 익숙하면
충분하며 두 시스템에 대한 사전 지식은 필요하지 않습니다.

구축 구조
=========

.. code-block:: text

   [0 환경 점검·도구 설치] → [1 Terraform+libvirt] → [2 Ansible]
     → [3 Kubespray] → [4 선행 요소] → [5 OpenStack-Helm] → [6 검증]

.. list-table:: 단계와 실행 명령
   :header-rows: 1
   :widths: 10 35 25 30

   * - 단계
     - 내용
     - 도구
     - 실행 명령
   * - 0
     - 환경 점검, 도구 설치
     - 쉘 스크립트
     - ``make preflight``, ``make install``
   * - 1
     - 노드 VM, 네트워크 생성
     - Terraform + libvirt
     - ``make stage-1``
   * - 2
     - 노드 사전 설정
     - Ansible
     - ``make stage-2``
   * - 3
     - Kubernetes 구축
     - Kubespray
     - ``make stage-3``
   * - 4
     - 선행 요소
     - kubectl, Helm
     - ``make stage-4``
   * - 5
     - OpenStack 배포
     - OpenStack-Helm
     - ``make stage-5``
   * - 6
     - 검증
     - kubectl, helm, openstack CLI
     - ``make stage-6``, ``make verify``

전체를 한 번에 실행하려면 ``make up`` 을 사용합니다.

.. note::
   ``make`` 명령은 키트 구현 예정입니다. 정해진 대상은 ``preflight``, ``install``,
   ``up``, ``stage-N`` (N 은 0~6), ``verify``, ``destroy`` 입니다.

.. list-table:: 노드 구성
   :header-rows: 1

   * - 노드
     - 역할
     - vCPU
     - 메모리
     - 디스크 (thin)
     - IP
   * - cp
     - Kubernetes 컨트롤 플레인
     - 4
     - 16GiB
     - 60GB
     - 192.168.100.10
   * - ctrl-worker
     - OpenStack 컨트롤 서비스
     - 16
     - 32GiB
     - 120GB
     - 192.168.100.11
   * - compute-1
     - 컴퓨트
     - 10
     - 32GiB
     - 80GB
     - 192.168.100.21
   * - compute-2
     - 컴퓨트
     - 10
     - 32GiB
     - 80GB
     - 192.168.100.22

.. note::
   사양은 시작점으로 정한 값이며 첫 설치 후 조정될 수 있습니다. IP 는 서버
   안의 가상 네트워크(192.168.100.0/24)에서만 쓰이는 주소입니다. 노드 안에서
   확인한 실제 값은 :doc:`infrastructure` 장에 있습니다.

기준 버전
=========

이 가이드의 모든 절차는 아래 버전으로 확인했습니다. 도구 버전은 저장소의
``versions.env`` 한 곳에서 관리합니다.

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - 구분
     - 항목
     - 버전
   * - OpenStack
     - 릴리스
     - 2026.1 (Gazpacho)
   * -
     - OpenStack-Helm
     - 태그 ``2026.1.0`` (커밋 ``c665eedfa``)
   * - Kubernetes
     - Kubernetes
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
     - 2.18.19
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

범위와 한계
===========

* 검증은 서비스 동작 확인(Keystone 토큰 발급, Glance 이미지 등록 등)까지
  입니다. 사용자 인스턴스(VM) 부팅은 다루지 않습니다.
* Kubespray 와 OpenStack-Helm 의 조합은 OpenStack-Helm 의 공식 검증
  대상이 아닙니다. 이 가이드의 절차는 실제 설치로 확인한 결과입니다.
* 노드가 VM 이므로 Nova 는 ``qemu`` 모드로 동작하며 성능에 한계가 있습니다.
* 스토리지는 Ceph 대신 노드 디스크를 쓰는 ``local-path`` 입니다. 볼륨이 한
  노드의 디스크에 있으므로 노드에 장애가 나면 데이터가 사라질 수 있습니다.
* 외부 네트워크(``br-ex``)는 설정하지 않습니다. 노드 VM 의 네트워크 인터페이스가
  하나뿐이라 건드리면 연결이 끊길 수 있기 때문입니다.
* 서버 한 대로 구성한 실습용 환경입니다. 운영 환경에는 그대로 쓰지 않습니다.
* Kubernetes 위에 OpenStack 을 올리는 구조만 다룹니다.
* 환경 전제: 외부 시간 서버(UDP 123)와 패키지·이미지 저장소(80, 443)에 접속할
  수 있어야 합니다.

이 가이드를 읽는 방법
=====================

각 장은 목표 → 선행 조건 → 수행 → 확인 → 자주 만나는 오류 순서로
구성됩니다. 각 단계는 ``make stage-N`` 한 번으로 실행할 수도 있고,
장에 나온 명령을 직접 입력하며 따라 할 수도 있습니다.

.. toctree::
   :maxdepth: 2
   :numbered:

   prerequisites
   infrastructure
   kubernetes
   prereq-components
   openstack-deploy
   verification
   troubleshooting