======================================
OpenStack ↔ Kubernetes 연동 인터페이스
======================================

가상화 기초·OpenStack·Kubernetes 세 레이어를 이해했다면, 다음은 두 기술을
실제로 잇는 표준 인터페이스입니다. 각 개념의 상세는 통합 패턴·네트워킹·
스토리지 섹션에서 다루며, 이 문서는 "무엇을 어디서 다루는지" 를 안내하는
지도(signpost) 역할을 합니다.

.. warning::

   **아래는 추가한 내용. 검토 후 기존 내용 삭제 필요.**

두 시스템을 함께 사용할 때는 어느 시스템이 아래에서 자원을 제공하는지부터
확인합니다. 같은 도구 이름이 나와도 배치 방향에 따라 역할이 달라집니다.

두 가지 결합 방향
------------------------------------------------------------

.. list-table::
   :header-rows: 1

   * - 방향
     - 기반 자원
     - 그 위에서 실행하는 것
     - 주요 연결
   * - OpenStack on Kubernetes
     - Kubernetes 클러스터
     - OpenStack API·에이전트·지원 서비스
     - Helm 차트와 Kubernetes API
   * - Kubernetes on OpenStack
     - OpenStack이 제공하는 VM·네트워크·스토리지
     - Kubernetes 노드와 애플리케이션
     - 클라우드 컨트롤러, Cinder CSI 등

Lab Kit의 노드 VM은 호스트 libvirt가 만들고, Kubespray가 그 VM에 Kubernetes를
구축합니다. OpenStack-Helm은 이 Kubernetes에 OpenStack을 배포합니다.
향후 OpenStack의 VM으로 별도 Kubernetes 클러스터를 만들 경우에는 두 번째
방향의 연동을 추가로 구성해야 합니다.

실행·네트워크·스토리지 경계
------------------------------------------------------------

.. list-table::
   :header-rows: 1

   * - 인터페이스 또는 구성요소
     - 연결 대상
     - 이해할 점
   * - CRI
     - kubelet ↔ 컨테이너 런타임
     - Pod의 컨테이너 실행 요청
   * - CNI
     - 컨테이너 네트워크 구성 ↔ 네트워크 플러그인
     - Pod 인터페이스와 네트워크 연결 구성
   * - CSI
     - Kubernetes ↔ 스토리지 드라이버
     - 볼륨 생성·연결·마운트 등의 작업
   * - OpenStack cloud-controller-manager
     - Kubernetes ↔ OpenStack API
     - 구성에 따라 클라우드 노드 정보와 로드밸런서 등 연동
   * - Cinder CSI
     - Kubernetes PVC ↔ Cinder 볼륨
     - OpenStack 위 Kubernetes의 영구 저장공간 연결

클라우드 연동에는 드라이버, 인증 정보, 권한과 지원 서비스가 필요합니다.
예를 들어 OpenStack 로드밸런서를 통한 Service 노출에는 해당 연동 설정과
사용 가능한 로드밸런서 서비스가 필요합니다.

Pod 네트워크와 인스턴스 네트워크
------------------------------------------------------------

실습에서는 Calico가 Kubernetes Pod 네트워크를 구성하고,
Neutron과 선택한 네트워크 백엔드가 OpenStack 인스턴스의 연결을 구성합니다.
Pod 통신 성공과 인스턴스의 외부 통신 성공은 서로 다른 점검입니다.

.. code-block:: text

   Kubernetes 영역
     Pod ↔ Service / DNS ↔ 다른 Pod

   OpenStack 영역
     사용자 VM ↔ Neutron 포트·네트워크 ↔ 라우터·외부 네트워크

또한 Ingress 컨트롤러를 통한 OpenStack API 접속과
Floating IP를 통한 사용자 VM 접속은 경로와 설정이 다릅니다.
문제를 진단할 때 요청을 보낸 위치와 목적지, 거치는 경로를 기록합니다.

저장공간을 연결할 때
------------------------------------------------------------

OpenStack on Kubernetes에서는 MariaDB나 Glance 등의 Pod가 저장공간을
필요로 할 수 있습니다. 수동 구축 기록은 ``general`` local-path를 사용했습니다.
local-path-provisioner는 노드의 로컬 경로를 활용하는 프로비저너이며,
이를 설치했다고 Cinder CSI가 구성되는 것은 아닙니다.
CSI의 개념과 볼륨 수명주기는 :doc:`kubernetes-csi` 를 참고합니다.

참고 문서
------------------------------------------------------------

* `OpenStack-Helm <https://docs.openstack.org/openstack-helm/latest/>`_
* `OpenStack 클라우드 연동 구성요소 <https://github.com/kubernetes/cloud-provider-openstack>`_
* `Kubernetes 네트워크 <https://kubernetes.io/docs/concepts/services-networking/>`_
* `local-path-provisioner <https://github.com/rancher/local-path-provisioner>`_