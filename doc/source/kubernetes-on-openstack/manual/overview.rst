개요 및 실습 환경
============================

구축 개요
------------

이 가이드에서는 단일 베어메탈 서버에 OpenStack을 구축하고,
OpenStack이 제공하는 가상 머신 위에 Kubernetes 클러스터를
생성하는 과정을 설명합니다.

베어메탈 서버란 가상 머신이 아닌 물리 서버를 의미합니다.

.. list-table:: 실습 서버 환경
   :header-rows: 1
   :widths: 35 65

   * - 항목
     - 구성
   * - 운영체제
     - Ubuntu 24.04.1 LTS
   * - CPU
     - 96개 논리 CPU
   * - 메모리
     - 125 GiB
   * - 디스크
     - 464 G
   * - 물리 네트워크 인터페이스
     - eth0 1개
   * - 가상화
     - KVM
   * - OpenStack
     - 2026.1
   * - Kubernetes 관리 클러스터
     - v1.36.4
   * - Kubernetes 워크로드 클러스터
     - v1.36.6

위 사양은 실제 실습에 사용한 서버의 사양이며,
구축에 필요한 최소 요구 사양을 의미하지 않습니다.

구축 구조
---------

.. code-block:: text

   Bare Metal Server
   |
   +-- OpenStack
   |   |
   |   +-- External Network
   |   +-- Router
   |   +-- Internal Network
   |       |
   |       +-- Control Plane VM
   |       +-- Worker VM 1
   |       +-- Worker VM 2
   |
   +-- Docker
       |
       +-- kind Management Cluster
           |
           +-- Cluster API
           +-- CAPO
           +-- ORC

관리 클러스터는 Kubernetes 클러스터의 생성과 삭제를
관리하는 역할을 합니다.

워크로드 클러스터는 OpenStack 가상 머신 위에 생성되며,
실제 컨테이너 애플리케이션을 실행하는 환경입니다.

사용 도구와 역할
----------------

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - 도구
     - 역할
   * - Kolla-Ansible
     - OpenStack 서비스를 컨테이너 형태로 배포
   * - image-builder
     - Kubernetes 노드에 사용할 가상 머신 이미지 생성
   * - Packer
     - 가상 머신 이미지 빌드
   * - Terraform
     - 네트워크, 라우터, 이미지 등 공용 자원 구성
   * - kind
     - Docker 기반 Kubernetes 관리 클러스터 생성
   * - Cluster API (CAPI)
     - Kubernetes 클러스터의 생성 및 삭제 관리
   * - CAPO
     - Cluster API와 OpenStack 인프라 연동
   * - ORC
     - Kubernetes를 통한 OpenStack 자원 관리
   * - Calico
     - Kubernetes 파드 간 네트워크 통신 제공
   * - OCCM
     - Kubernetes 노드와 OpenStack 인프라 연동

워크로드 클러스터 구성
----------------------

.. list-table::
   :header-rows: 1

   * - 노드
     - 수량
     - vCPU
     - RAM
     - 디스크
   * - Control Plane
     - 1
     - 4
     - 8 GiB
     - 60 GB
   * - Worker
     - 2
     - 4
     - 8 GiB
     - 60 GB

명령어 실행 위치
----------------

이 문서의 구축 명령어는 별도 안내가 없는 경우
원격 Ubuntu 실습 서버에서 실행합니다.

로컬 컴퓨터에서는 SSH를 이용하여 서버에 접속합니다.

.. code-block:: bash

   ssh <USER>@<SERVER_IP>

``<USER>`` 와 ``<SERVER_IP>`` 는 각각 실제 서버 계정과
서버 주소로 변경합니다.

오래 걸리는 작업은 SSH 연결이 끊어져도 계속 실행할 수
있도록 tmux 세션에서 진행하는 것을 권장합니다.

.. code-block:: bash

   tmux new -s kit

기존 세션에 다시 접속하려면 다음 명령어를 사용합니다.

.. code-block:: bash

   tmux attach -t kit

관리 클러스터와 워크로드 클러스터 구분
--------------------------------------

관리 클러스터를 대상으로 명령어를 실행하는 경우
``--context kind-mgmt`` 옵션을 사용합니다.

.. code-block:: bash

   kubectl --context kind-mgmt get nodes

워크로드 클러스터를 대상으로 실행하는 경우
해당 클러스터의 kubeconfig 파일을 지정합니다.

.. code-block:: bash

   export KUBECONFIG=~/capi/k8s-lab.kubeconfig
   kubectl get nodes

.. warning::

   두 클러스터는 서로 다른 환경입니다.
   자원을 변경하거나 삭제하기 전에는 반드시 명령어의
   실행 대상을 확인해야 합니다.

구축 범위와 한계
----------------

이 실습에서는 단일 서버를 기반으로 Kubernetes 클러스터의
생성, 네트워크 동작, 클라우드 연동 및 삭제를 검증합니다.

다음 항목은 이번 실습의 구축 범위에 포함하지 않습니다.

* OpenStack 고가용성 구성
* 다중 물리 서버 구성
* Octavia 기반 로드밸런서
* Ingress 구성
* Cinder 기반 영구 볼륨 검증
* 운영 환경 수준의 장기 안정성 검증

보안 및 민감 정보
-----------------

다음 정보는 공개 저장소, 문서 및 공유 로그에 포함하지 않습니다.

* 서버 공인 IP와 실제 계정 이름
* SSH 개인 키
* passwords.yml
* admin-openrc.sh
* clouds.yaml 및 cloud.conf
* kubeconfig
* Terraform 상태 파일

.. important::

   Kubernetes Secret은 기본적으로 Base64로 인코딩됩니다.
   Base64 인코딩은 암호화가 아니므로 Secret의 내용을
   공개하거나 공유하지 않아야 합니다.
