4단계. CAPO로 Kubernetes 클러스터 생성
======================================

이 단계에서는 CAPO를 이용하여 OpenStack 위에
Kubernetes 워크로드 클러스터를 생성합니다.

2단계에서 Terraform으로 생성한 공용 네트워크와
이미지, flavor 및 키페어를 재사용합니다.

워크로드 클러스터는 컨트롤플레인 노드 1대와
워커 노드 2대로 구성합니다.

사전 조건
---------

* OpenStack 서비스 정상 동작
* Terraform 공용 자원 생성 완료
* kind 관리 클러스터 정상 동작
* Cluster API 및 CAPO 설치 완료

ORC 설치
--------

ORC(OpenStack Resource Controller)는 Kubernetes
리소스를 통해 OpenStack 자원을 관리하는 구성 요소입니다.

이번 실습에서 CAPO v0.15.1은 ORC 관련 CRD가
설치되지 않은 상태에서 정상적으로 동작하지 않았습니다.

ORC v2.0.3을 설치합니다.

.. code-block:: bash

   ORC_VERSION=v2.0.3
   ORC_URL=https://github.com/k-orc/openstack-resource-controller

   kubectl --context kind-mgmt apply --server-side \
       -f "$ORC_URL/releases/download/$ORC_VERSION/install.yaml"

설치가 완료될 때까지 기다립니다.

.. code-block:: bash

   kubectl --context kind-mgmt wait \
       --for=condition=Available deployment --all \
       -n orc-system --timeout=180s

CAPO 컨트롤러를 재시작합니다.

.. code-block:: bash

   kubectl --context kind-mgmt rollout restart \
       deployment/capo-controller-manager -n capo-system

   kubectl --context kind-mgmt rollout status \
       deployment/capo-controller-manager \
       -n capo-system --timeout=180s

   kubectl --context kind-mgmt get pods -n capo-system
   kubectl --context kind-mgmt get pods -n orc-system

CAPO 컨트롤러가 재시작을 반복하지 않는지 확인합니다.

OpenStack 공용 자원 확인
------------------------

Kolla-Ansible 가상환경에서 인증 정보를 불러옵니다.

.. code-block:: bash

   source ~/kolla-venv/bin/activate
   source /etc/kolla/admin-openrc.sh

   openstack network show ext-net -c id -f value
   openstack availability zone list --compute
   openstack subnet show k8s-subnet
   openstack router show k8s-router

외부 네트워크 ID는 환경마다 다르므로 실제 조회 결과를
사용해야 합니다.

OpenStack 인증 Secret 생성
---------------------------

CAPO가 OpenStack API에 접근할 수 있도록 인증 정보를
관리 클러스터의 Secret으로 등록합니다.

.. code-block:: bash

   kubectl --context kind-mgmt -n default \
       create secret generic k8s-lab-cloud-config \
       --from-file=clouds.yaml=/etc/kolla/clouds.yaml

   kubectl --context kind-mgmt -n default \
       label secret k8s-lab-cloud-config \
       clusterctl.cluster.x-k8s.io/move=true

.. warning::

   이번 실습에서는 구축 과정의 단순화를 위해 OpenStack
   관리자 인증 정보를 사용했습니다.

   실제 운영 환경에서는 필요한 권한만 가진 전용 계정
   또는 적절한 application credential 사용을 권장합니다.

   Secret의 내용을 출력하거나 공개하지 않습니다.

관리 클러스터와 노드 네트워크 연결
-----------------------------------

관리 클러스터에서 OpenStack에 생성되는 Kubernetes
API 서버에 접근할 수 있어야 합니다.

이번 실습에서는 호스트의 기존 방화벽으로 인해
관리 클러스터에서 워크로드 API 서버로 연결되지 않는
문제가 발생했습니다.

.. warning::

   아래 규칙은 실습 서버의 네트워크 대역에 맞춘 설정입니다.
   다른 환경에서는 인터페이스와 네트워크 대역을 먼저 확인합니다.

.. code-block:: bash

   sudo iptables -C FORWARD \
       -s 172.17.0.0/16 -d 10.20.20.0/24 \
       -o veth-host -j ACCEPT 2>/dev/null || \
   sudo iptables -I FORWARD 1 \
       -s 172.17.0.0/16 -d 10.20.20.0/24 \
       -o veth-host -j ACCEPT

위 규칙은 관리 클러스터에서 OpenStack 외부 네트워크로
전달되는 패킷을 허용합니다.

클러스터 매니페스트 준비
------------------------

매니페스트는 Kubernetes 클러스터의 원하는 구성과
상태를 YAML 형식으로 정의한 파일입니다.

CAPO의 without-lb 템플릿을 사용합니다.
이번 실습에서는 Octavia를 구성하지 않았기 때문입니다.

작업 디렉터리를 생성합니다.

.. code-block:: bash

   mkdir -p ~/capi
   cd ~/capi

템플릿 생성에 필요한 환경변수를 확인합니다.

.. code-block:: bash

   clusterctl generate cluster k8s-lab \
       --kubeconfig-context kind-mgmt \
       --infrastructure openstack:v0.15.1 \
       --flavor without-lb \
       --kubernetes-version v1.36.6 \
       --control-plane-machine-count=1 \
       --worker-machine-count=2 \
       --list-variables

위 결과를 기준으로 필요한 변수를 설정합니다.
인증 관련 변수의 값을 공개하거나 기록하지 않습니다.

다음 명령어로 초기 매니페스트를 생성합니다.

.. code-block:: bash

   umask 077

   clusterctl generate cluster k8s-lab \
       --kubeconfig-context kind-mgmt \
       --infrastructure openstack:v0.15.1 \
       --flavor without-lb \
       --kubernetes-version v1.36.6 \
       --control-plane-machine-count=1 \
       --worker-machine-count=2 \
       > ~/capi/k8s-lab.yaml

매니페스트 수정
~~~~~~~~~~~~~~~

생성한 매니페스트를 편집합니다.

.. code-block:: bash

   nano ~/capi/k8s-lab.yaml

기본 템플릿에서는 새로운 OpenStack 네트워크와 서브넷을
생성하도록 구성되어 있습니다.

이번 실습에서는 Terraform으로 생성한 기존 네트워크를
재사용하므로 해당 부분을 수정합니다.

OpenStackCluster 리소스의 managedSubnets 항목을 제거하고
기존 네트워크와 서브넷을 지정합니다.

다음은 수정할 주요 항목입니다.

.. code-block:: yaml

   apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
   kind: OpenStackCluster
   metadata:
     name: k8s-lab
     namespace: default
   spec:
     apiServer: {}
     externalNetwork:
       id: "<EXT_NET_ID>"
     identityRef:
       cloudName: kolla-admin-internal
       name: k8s-lab-cloud-config
     network:
       filter:
         name: k8s-net
     subnets:
       - filter:
           name: k8s-subnet

.. important::

   위 YAML은 전체 매니페스트가 아닌 수정 대상의 예시입니다.

   기존 템플릿의 managedSecurityGroups 설정과 나머지
   Cluster API 리소스는 유지해야 합니다.

   EXT_NET_ID는 앞에서 조회한 외부 네트워크 ID로
   변경합니다.

   인증 Secret은 별도로 생성했으므로 템플릿에 포함된
   Secret 문서는 제거합니다.

나머지 리소스에서 다음 설정을 확인합니다.

.. list-table::
   :header-rows: 1
   :widths: 45 55

   * - 항목
     - 설정값
   * - Cluster 이름
     - k8s-lab
   * - Kubernetes 버전
     - v1.36.6
   * - Control Plane replicas
     - 1
   * - Worker replicas
     - 2
   * - Flavor
     - k8s-node
   * - Image
     - ubuntu-2404-kube-v1.36.6
   * - SSH Key
     - k8s-key
   * - Failure Domain
     - nova
   * - Cloud Provider
     - external

매니페스트 적용
---------------

실제 자원을 생성하기 전에 서버 측 검증을 수행합니다.

.. code-block:: bash

   kubectl --context kind-mgmt apply \
       --dry-run=server -f ~/capi/k8s-lab.yaml

모든 리소스가 정상적으로 검증되면 적용합니다.

.. code-block:: bash

   time kubectl --context kind-mgmt apply \
       -f ~/capi/k8s-lab.yaml

CAPO가 OpenStack API를 통해 가상 머신과 관련 자원을
생성하기 시작합니다.

클러스터 생성 상태 확인
------------------------

.. code-block:: bash

   kubectl --context kind-mgmt get cluster,machine -A

   kubectl --context kind-mgmt get \
       kubeadmcontrolplane,openstackmachine -A

OpenStack에서 생성된 가상 머신도 확인합니다.

.. code-block:: bash

   openstack server list
   openstack floating ip list

컨트롤플레인 가상 머신과 워커 가상 머신이 생성되어
ACTIVE 상태가 되는지 확인합니다.

워크로드 클러스터 접속
----------------------

워크로드 클러스터에 접속할 수 있는 kubeconfig 파일을
생성합니다.

.. code-block:: bash

   clusterctl get kubeconfig k8s-lab \
       --kubeconfig-context kind-mgmt \
       > ~/capi/k8s-lab.kubeconfig

   chmod 600 ~/capi/k8s-lab.kubeconfig

생성된 kubeconfig를 이용하여 노드 상태를 확인합니다.

.. code-block:: bash

   kubectl --kubeconfig ~/capi/k8s-lab.kubeconfig \
       get nodes -o wide

   kubectl --kubeconfig ~/capi/k8s-lab.kubeconfig \
       get pods -A

완료 기준
---------

* KubeadmControlPlane INITIALIZED 상태 true
* OpenStack 가상 머신 3대 생성
* Cluster API Machine 3개 Running
* Kubernetes 노드 3개 등록
* Kubernetes 버전 v1.36.6
* 컨트롤플레인 API 서버 접근 가능

.. note::

   이 단계에서는 Calico가 아직 설치되지 않았으므로
   노드가 NotReady 상태이고 CoreDNS가 Pending 상태인
   것이 예상되는 결과입니다.

   다음 단계에서 네트워크 구성 요소를 설치한 뒤
   노드가 Ready 상태로 변경되는지 확인합니다.

참고 문서
---------

* `CAPO Configuration
  <https://cluster-api-openstack.sigs.k8s.io/clusteropenstack/configuration>`_
* `ORC Installation
  <https://k-orc.pages.dev/installation>`_
* `CAPO API Reference
  <https://cluster-api-openstack.sigs.k8s.io/api/v1beta2/api>`_
