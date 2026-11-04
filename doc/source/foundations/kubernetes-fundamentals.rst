====================
Kubernetes 핵심 개념
====================

Kubernetes는 여러 노드에 컨테이너 애플리케이션을 배치하고,
사용자가 선언한 상태를 유지하도록 동작하는 시스템입니다.
사용자가 원하는 복제본 수와 설정을 API에 제출하면 컨트롤러와 노드 구성요소가
실제 상태를 그에 맞추어 조정합니다.

클러스터의 구성
------------------------------------------------------------

클러스터는 제어 기능을 담당하는 컨트롤 플레인과 워크로드를 실행하는
노드로 구성됩니다. 역할의 배치는 설치 방식과 스케줄링 설정에 따라 달라집니다.

.. list-table::
   :header-rows: 1

   * - 구성요소
     - 주요 역할
   * - kube-apiserver
     - Kubernetes API 요청의 진입점
   * - etcd
     - 클러스터의 API 객체와 상태 저장
   * - kube-scheduler
     - 아직 배치되지 않은 Pod에 적합한 노드 선택
   * - kube-controller-manager
     - 실제 상태를 선언된 상태에 맞추는 제어 작업 수행
   * - kubelet
     - 각 노드에서 Pod의 컨테이너 실행 상태 관리
   * - 컨테이너 런타임
     - 이미지를 준비하고 컨테이너 실행. 실습에서는 containerd 사용

실습의 ``cp`` 는 Kubernetes 컨트롤 플레인이고,
``ctrl-worker`` 는 OpenStack 제어 서비스가 배치되는 워커입니다.
두 이름의 control은 각각 관리하는 시스템을 기준으로 이해합니다.

문서를 읽을 때 필요한 리소스
------------------------------------------------------------

.. list-table::
   :header-rows: 1

   * - 리소스
     - 뜻
     - 사용 예
   * - Pod
     - 함께 배치되는 한 개 이상의 컨테이너 묶음
     - OpenStack API 서버 실행
   * - Deployment
     - 원하는 Pod 복제본과 업데이트 관리
     - API 서비스의 복제본 유지
   * - StatefulSet
     - Pod의 식별자와 스토리지 연결을 안정적으로 관리
     - 상태를 유지하는 서비스 구성
   * - DaemonSet
     - 선택된 노드마다 Pod 실행
     - 노드별 에이전트 실행
   * - Job / CronJob
     - 완료되는 작업 / 일정에 따른 작업
     - DB 초기화 또는 정리 작업
   * - Namespace
     - 리소스를 구분하는 논리적 범위
     - openstack 네임스페이스
   * - ConfigMap / Secret
     - 설정 데이터 / 민감한 설정 데이터 전달
     - 서비스 설정과 인증 정보

Secret의 저장·조회 권한과 저장 시 암호화 설정도 관리해야 합니다.
리소스 이름만으로 데이터 보호가 모두 보장되지는 않습니다.

네트워크와 스토리지
------------------------------------------------------------

Service는 바뀔 수 있는 Pod 집합에 안정적인 접근 지점을 제공합니다.
Ingress는 HTTP·HTTPS 요청의 라우팅 규칙을 정의하며 이를 처리하는
Ingress 컨트롤러가 필요합니다. 클러스터 DNS 이름은 클러스터 내부에서
사용하도록 구성되므로 호스트에서 같은 이름이 자동으로 풀리지는 않습니다.

PVC는 저장공간 요청, PV는 제공된 저장공간을 나타냅니다.
StorageClass는 동적 볼륨 생성 방식과 정책을 선택합니다.
자세한 내용은 :doc:`kubernetes-csi` 에서 설명합니다.

레이블과 배치
------------------------------------------------------------

레이블은 리소스에 붙이는 키와 값입니다. Pod의 nodeSelector 같은 배치 조건이
노드 레이블을 선택하면 특정 역할의 노드에 워크로드를 배치할 수 있습니다.
taint와 toleration도 배치에 영향을 줍니다. 레이블을 붙이는 작업과
실제 Pod가 원하는 노드에서 실행되는지 확인하는 작업을 함께 수행합니다.

상태 확인
------------------------------------------------------------

클러스터 접근 설정이 준비된 호스트에서 다음 읽기 전용 명령을 사용합니다.

.. code-block:: bash

   kubectl get nodes -o wide
   kubectl get pods -n openstack -o wide
   kubectl get svc,pvc -n openstack
   kubectl get events -n openstack --sort-by=.metadata.creationTimestamp

Running 파드의 Ready 상태와 성공한 Job의 Completed 상태를 구분합니다.
파드가 실행 중이라는 사실과 OpenStack API의 실제 기능 성공도 각각 확인합니다.

참고 문서
------------------------------------------------------------

* `Kubernetes 구성요소 <https://kubernetes.io/docs/concepts/overview/components/>`_
* `Kubernetes 네트워크 <https://kubernetes.io/docs/concepts/services-networking/>`_
* `Kubernetes 영구 볼륨 <https://kubernetes.io/docs/concepts/storage/persistent-volumes/>`_