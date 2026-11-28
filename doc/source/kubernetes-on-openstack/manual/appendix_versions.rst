부록 A. 사용 도구 및 버전
=========================

이 문서는 Kubernetes on OpenStack 수동 구축 과정에서
실제로 사용한 주요 도구와 구성 요소의 버전을 정리합니다.

동일한 구축 환경을 재현하기 위해 가능한 한 동일한
버전의 도구와 컨테이너 이미지를 사용합니다.

호스트 및 OpenStack 환경
-------------------------

.. list-table::
   :header-rows: 1
   :widths: 50 50

   * - 항목
     - 버전
   * - 호스트 운영체제
     - Ubuntu 24.04.1 LTS
   * - OpenStack
     - 2026.1
   * - Kolla-Ansible
     - 22.2.0
   * - Ansible Core (Kolla)
     - 2.20.11
   * - Docker Python SDK
     - 7.2.0
   * - dbus-python
     - 1.5.1
   * - python-openstackclient
     - 10.5.0
   * - openstacksdk
     - 4.22.0

OpenStack 컨테이너 이미지는 다음 태그를 사용했습니다.

.. code-block:: text

   2026.1-ubuntu-noble

이미지 빌드 환경
----------------

.. list-table::
   :header-rows: 1
   :widths: 50 50

   * - 항목
     - 버전
   * - image-builder
     - 커밋 704689a7e24c
   * - Packer
     - v1.9.5
   * - Packer Ansible Plugin
     - v1.1.3
   * - Packer Goss Plugin
     - v3.2.14
   * - Packer QEMU Plugin
     - v1.1.3
   * - Ansible Core (image-builder)
     - 2.18.18
   * - 기반 Ubuntu ISO
     - Ubuntu 24.04.4
   * - 생성된 노드 이미지 운영체제
     - Ubuntu 24.04.5 LTS
   * - Kubernetes
     - v1.36.6
   * - containerd
     - 2.3.7
   * - CNI Plugins
     - 1.2.0

노드 이미지 정보
----------------

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - 항목
     - 설정
   * - 이미지 이름
     - ubuntu-2404-kube-v1.36.6
   * - 디스크 형식
     - qcow2
   * - 컨테이너 형식
     - bare
   * - 가상 디스크 크기
     - 20 GiB
   * - 생성된 이미지 파일 크기
     - 약 4.3 GB

인프라 구성 도구
----------------

.. list-table::
   :header-rows: 1
   :widths: 50 50

   * - 항목
     - 버전
   * - Terraform
     - 1.15.9
   * - Terraform OpenStack Provider
     - 3.4.0

관리 클러스터 및 워크로드 클러스터
-----------------------------------

.. list-table::
   :header-rows: 1
   :widths: 50 50

   * - 항목
     - 버전
   * - kind
     - v0.33.0
   * - 관리 클러스터 Kubernetes
     - v1.36.4
   * - 워크로드 클러스터 Kubernetes
     - v1.36.6
   * - kubectl
     - v1.35.4
   * - clusterctl
     - v1.14.3
   * - Cluster API
     - v1.14.3
   * - Kubeadm Bootstrap Provider
     - v1.14.3
   * - Kubeadm Control Plane Provider
     - v1.14.3
   * - CAPO
     - v0.15.1
   * - ORC
     - v2.0.3
   * - cert-manager
     - v1.21.2
   * - Calico
     - v3.33.0
   * - OCCM
     - v1.36.0

관리 클러스터 이미지
--------------------

관리 클러스터의 Kubernetes 버전은 Cluster API의
지원 범위를 고려하여 v1.36.4로 지정했습니다.

재현성을 확보하기 위해 이미지 태그뿐만 아니라
digest도 함께 지정했습니다.

.. code-block:: text

   kindest/node:v1.36.4

.. code-block:: text

   sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed

테스트용 컨테이너 이미지
------------------------

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - 이미지
     - 사용 목적
   * - nginx:1.27-alpine
     - 웹 서비스 제공
   * - busybox:1.37
     - 파드 네트워크 및 DNS 통신 확인

주요 버전 선택 이유
-------------------

Kolla-Ansible
~~~~~~~~~~~~~

구축 환경의 재현성을 확보하기 위해 Kolla-Ansible을
22.2.0 태그로 지정하여 설치했습니다.

openstacksdk
~~~~~~~~~~~~

실제 구축 과정에서 openstacksdk 4.23.0의 패키지
파일 누락으로 OpenStack CLI 실행 오류가 발생했습니다.

이를 해결하기 위해 4.22.0으로 버전을 고정했습니다.

Kubernetes
~~~~~~~~~~

관리 클러스터와 워크로드 클러스터는 서로 다른
Kubernetes 버전을 사용합니다.

관리 클러스터는 Cluster API의 지원 범위를 고려하여
v1.36.4를 사용했으며, 워크로드 클러스터는 직접 빌드한
v1.36.6 노드 이미지를 사용했습니다.

Calico 및 OCCM
~~~~~~~~~~~~~~~~~~~~

워크로드 클러스터의 Kubernetes 버전에 맞추어
Calico v3.33.0과 OCCM v1.36.0을 사용했습니다.

버전 관리 시 주의사항
---------------------

위 표는 실제 수동 구축 과정에서 사용한 버전을
나타냅니다.

모든 구성 요소의 공식 지원 범위나 상호 호환성이
검증되었다는 의미는 아닙니다.

특히 CAPO와 ORC의 조합 및 CAPO의 Kubernetes 1.36
공식 지원 여부는 별도로 확인이 필요합니다.

Kolla-Ansible과 image-builder에서 사용하는 Ansible
Core 버전이 다르므로 Python 가상환경을 구분하여
사용합니다.

컨테이너 이미지 및 외부 설치 자료의 태그는 시간이
지나면서 변경되거나 제공이 중단될 수 있습니다.

재현성을 높이기 위해 이미지 digest 또는 소스 코드
커밋을 고정하는 것을 권장합니다.

관련 공식 문서는 :doc:`appendix_manual_refs` 문서를
참고합니다.
