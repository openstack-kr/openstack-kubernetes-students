5단계. Calico 및 OCCM 설치와 동작 검증
======================================

이 단계에서는 워크로드 클러스터에 Calico와 OCCM을
설치하여 Kubernetes 네트워크와 OpenStack 연동 기능을
구성합니다.

Calico는 Kubernetes 파드 간 네트워크 통신을 제공하는
CNI(Container Network Interface) 구성 요소입니다.

OCCM(OpenStack Cloud Controller Manager)은 Kubernetes
노드와 OpenStack 가상 머신의 정보를 연동하는 구성 요소입니다.

사전 조건
---------

* 4단계 완료
* Kubernetes 노드 3개 등록
* 워크로드 클러스터 kubeconfig 존재
* 노드에서 OpenStack API 접근 가능
* 노드에서 외부 이미지 레지스트리 접근 가능

작업 대상 설정
--------------

이 단계의 kubectl 명령어는 워크로드 클러스터를 대상으로
실행합니다.

.. code-block:: bash

   export KUBECONFIG=~/capi/k8s-lab.kubeconfig
   kubectl get nodes

관리 클러스터가 아닌 워크로드 클러스터의 노드 3개가
표시되는지 확인합니다.

Calico 매니페스트 다운로드
--------------------------

실습에서는 Kubernetes v1.36.6에 맞추어
Calico v3.33.0을 사용했습니다.

.. code-block:: bash

   mkdir -p ~/capi/calico
   cd ~/capi/calico

   V=v3.33.0
   B=https://raw.githubusercontent.com/projectcalico/calico

   curl -fsSLO "$B/$V/manifests/v3_projectcalico_org.yaml"
   curl -fsSLO "$B/$V/manifests/tigera-operator.yaml"
   curl -fsSLO "$B/$V/manifests/custom-resources.yaml"

Calico 네트워크 설정
--------------------

OpenStack의 네트워크 및 보안 그룹 구성에 맞추어
Calico의 캡슐화 방식을 IPIP로 설정합니다.

IPIP는 기존 IP 패킷을 다른 IP 패킷으로 감싸서
노드 간에 전달하는 방식입니다.

원본 설정 파일을 보존하기 위해 사본을 생성합니다.

.. code-block:: bash

   cp custom-resources.yaml custom-resources-ipip.yaml

   sed -i 's/encapsulation: VXLANCrossSubnet/encapsulation: IPIP/' \
       custom-resources-ipip.yaml

   diff custom-resources.yaml custom-resources-ipip.yaml

다음 항목이 변경되었는지 확인합니다.

.. code-block:: yaml

   encapsulation: IPIP

파드 네트워크 대역은 이번 실습에서 192.168.0.0/16을
사용했습니다.

.. note::

   IPIP는 이번 실습에서 정상 동작한 설정입니다.
   기본 캡슐화 방식인 VXLANCrossSubnet과의 비교 시험은
   수행하지 않았습니다.

Calico 설치
-----------

Calico CRD, Tigera Operator 및 사용자 정의 설정을
순서대로 설치합니다.

CRD는 Kubernetes에 새로운 리소스 유형을 정의하는
기능입니다.

.. code-block:: bash

   kubectl create -f v3_projectcalico_org.yaml
   kubectl create -f tigera-operator.yaml
   kubectl create -f custom-resources-ipip.yaml

이번 실습에서 사용한 CRD 파일의 크기가 크므로
kubectl apply 대신 kubectl create를 사용합니다.

설치 진행 상태를 확인합니다.

.. code-block:: bash

   kubectl get tigerastatus
   kubectl -n calico-system get pods
   kubectl get nodes

OCCM 인증 설정
--------------

OCCM이 OpenStack API에 접근하기 위한 설정 파일을
생성합니다.

.. code-block:: bash

   mkdir -p ~/capi/occm
   cd ~/capi/occm
   umask 077
   nano cloud.conf

다음 항목을 작성합니다.

.. code-block:: ini

   [Global]
   auth-url=http://10.10.10.254:5000
   username="<OPENSTACK_USERNAME>"
   password="<OPENSTACK_PASSWORD>"
   tenant-name="<OPENSTACK_PROJECT>"
   domain-name="<OPENSTACK_DOMAIN>"
   region="<OPENSTACK_REGION>"

   [LoadBalancer]
   enabled=false

실제 인증 정보는 서버의 /etc/kolla/clouds.yaml 중
kolla-admin-internal 항목을 기준으로 작성합니다.

.. important::

   이번 실습 환경에는 Octavia가 설치되어 있지 않습니다.

   OCCM의 LoadBalancer 기능이 활성화되면 필요한
   OpenStack 서비스 엔드포인트를 찾지 못하여
   컨트롤러가 반복 종료될 수 있습니다.

   따라서 LoadBalancer의 enabled 값을 false로 설정합니다.

설정 파일의 접근 권한을 제한합니다.

.. code-block:: bash

   chmod 600 cloud.conf

OCCM 인증 Secret 생성
---------------------

.. code-block:: bash

   kubectl -n kube-system create secret generic cloud-config \
       --from-file=cloud.conf

Secret 생성이 성공한 것을 확인한 뒤 임시 설정 파일을
삭제합니다.

.. code-block:: bash

   rm -v cloud.conf

.. warning::

   cloud.conf에는 OpenStack 인증 정보가 포함됩니다.
   실제 값을 문서나 저장소에 기록하지 않습니다.

OCCM 설치
---------

Kubernetes v1.36에 맞추어 OCCM v1.36.0을 사용합니다.

.. code-block:: bash

   cd ~/capi/occm

   REPO=https://raw.githubusercontent.com/kubernetes
   T=$REPO/cloud-provider-openstack/v1.36.0
   T=$T/manifests/controller-manager

   for file in \
       cloud-controller-manager-roles.yaml \
       cloud-controller-manager-role-bindings.yaml \
       openstack-cloud-controller-manager-ds.yaml
   do
       curl -fsSLO "$T/$file"
   done

매니페스트를 적용합니다.

.. code-block:: bash

   kubectl apply \
       -f cloud-controller-manager-roles.yaml \
       -f cloud-controller-manager-role-bindings.yaml \
       -f openstack-cloud-controller-manager-ds.yaml

OCCM 상태를 확인합니다.

.. code-block:: bash

   kubectl -n kube-system rollout status \
       ds/openstack-cloud-controller-manager

   kubectl -n kube-system get pods

Calico Typha 통신 허용
----------------------

Calico Typha는 Kubernetes 클러스터의 네트워크 상태
정보를 Calico 노드에 전달하는 구성 요소입니다.

이번 실습에서는 OpenStack 보안 그룹에 TCP 5473
포트가 허용되어 있지 않아 Calico가 정상적으로
초기화되지 않는 문제가 발생했습니다.

OpenStack 명령어를 실행할 수 있는 가상환경에서
인증 정보를 설정합니다.

.. code-block:: bash

   source ~/kolla-venv/bin/activate

   export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
   export OS_CLOUD=kolla-admin-internal

보안 그룹의 이름을 확인합니다.

.. code-block:: bash

   openstack security group list

이번 실습에서는 다음 이름의 보안 그룹을 사용했습니다.

.. code-block:: bash

   PREFIX=k8s-cluster-default-k8s-lab
   CP_NAME=$PREFIX-secgroup-controlplane
   W_NAME=$PREFIX-secgroup-worker

   CP=$(openstack security group show "$CP_NAME" -c id -f value)
   WK=$(openstack security group show "$W_NAME" -c id -f value)

보안 그룹의 기존 규칙을 확인합니다.

.. code-block:: bash

   openstack security group rule list "$WK"

필요한 규칙이 없는 경우 다음 명령어를 실행합니다.

.. code-block:: bash

   openstack security group rule create "$WK" \
       --ingress --protocol tcp --dst-port 5473 \
       --remote-group "$CP" \
       --description "Calico Typha from control plane"

   openstack security group rule create "$WK" \
       --ingress --protocol tcp --dst-port 5473 \
       --remote-group "$WK" \
       --description "Calico Typha from workers"

TCP 5473 포트의 접근 범위는 해당 컨트롤플레인 및
워커 보안 그룹으로 제한합니다.

.. note::

   실제 실습에서는 보안 그룹 ID를 직접 사용했습니다.
   위 명령어는 재현 편의를 위해 이름으로 ID를 조회하는
   방식으로 정리했습니다.

Calico 및 OCCM 상태 확인
------------------------

워크로드 클러스터에서 다음 명령어를 실행합니다.

.. code-block:: bash

   export KUBECONFIG=~/capi/k8s-lab.kubeconfig

   kubectl get tigerastatus
   kubectl -n calico-system get pods
   kubectl -n kube-system get pods
   kubectl get nodes -o wide

Calico 구성 요소가 Available 상태이고,
OCCM 파드가 Running 상태인지 확인합니다.

검증 b. Kubernetes 노드 상태
----------------------------------------

.. code-block:: bash

   kubectl get nodes -o wide

컨트롤플레인 1대와 워커 2대가 모두 Ready 상태인지
확인합니다.

검증 c. 배포 상태
-----------------

.. code-block:: bash

   kubectl get pods -A
   kubectl get jobs -A

시스템 파드가 정상적으로 실행 중인지 확인합니다.

이번 실습에서는 시스템 파드 25개가 정상적으로
동작했으며, 확인 대상 Job은 존재하지 않았습니다.

검증 d. 서비스 동작
-------------------

서로 다른 워커 노드에 테스트용 파드를 하나씩 배치하여
파드 간 통신과 Kubernetes Service 동작을 확인합니다.

먼저 워커 노드 이름을 확인합니다.

.. code-block:: bash

   kubectl get nodes

테스트 매니페스트를 생성합니다.

.. code-block:: bash

   nano ~/capi/d-test.yaml

다음 내용을 작성합니다.

.. code-block:: yaml

   apiVersion: v1
   kind: Namespace
   metadata:
     name: d-test
   ---
   apiVersion: v1
   kind: Pod
   metadata:
     name: web-a
     namespace: d-test
     labels:
       app: web
   spec:
     nodeName: "<WORKER_1_NAME>"
     containers:
       - name: nginx
         image: nginx:1.27-alpine
         ports:
           - containerPort: 80
   ---
   apiVersion: v1
   kind: Pod
   metadata:
     name: client-b
     namespace: d-test
   spec:
     nodeName: "<WORKER_2_NAME>"
     containers:
       - name: busybox
         image: busybox:1.37
         command: ["sh", "-c", "sleep 3600"]
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: web
     namespace: d-test
   spec:
     type: ClusterIP
     selector:
       app: web
     ports:
       - port: 80
         targetPort: 80

WORKER_1_NAME과 WORKER_2_NAME을 서로 다른 워커
노드의 실제 이름으로 변경합니다.

.. code-block:: bash

   kubectl apply -f ~/capi/d-test.yaml

   kubectl -n d-test wait \
       --for=condition=Ready pod --all --timeout=180s

   kubectl -n d-test get pods -o wide
   kubectl -n d-test get svc

파드 간 직접 통신
~~~~~~~~~~~~~~~~~

.. code-block:: bash

   WEB_IP=$(kubectl -n d-test get pod web-a \
       -o jsonpath='{.status.podIP}')

   kubectl -n d-test exec client-b -- \
       wget -qO- -T 5 "http://$WEB_IP"

nginx 웹 페이지의 HTML 응답이 반환되는지 확인합니다.

DNS 확인
~~~~~~~~

.. code-block:: bash

   kubectl -n d-test exec client-b -- \
       nslookup web.d-test.svc.cluster.local

Service 이름이 ClusterIP로 정상 변환되는지 확인합니다.

Service 접근 확인
~~~~~~~~~~~~~~~~~

.. code-block:: bash

   kubectl -n d-test exec client-b -- \
       wget -qO- -T 5 http://web

Service 이름으로 nginx에 접근할 수 있는지 확인합니다.

테스트 자원 정리
~~~~~~~~~~~~~~~~

테스트가 완료되면 테스트 전용 네임스페이스만 삭제합니다.

.. code-block:: bash

   kubectl delete namespace d-test

검증 e. OpenStack 클라우드 연동
-------------------------------

Kubernetes 노드의 providerID를 확인합니다.

.. code-block:: bash

   kubectl get nodes \
       -o custom-columns=NAME:.metadata.name,PROVIDERID:.spec.providerID

OpenStack에서 실제 가상 머신 ID를 확인합니다.

.. code-block:: bash

   openstack server list --name k8s-lab \
       -c ID -c Name -c Networks

Kubernetes 노드의 providerID는 다음 형식입니다.

.. code-block:: text

   openstack:///<INSTANCE_ID>

providerID에 포함된 인스턴스 ID가 OpenStack 서버 ID와
일치하는지 확인합니다.

노드의 내부 IP와 OpenStack 가상 머신의 네트워크
주소도 비교합니다.

완료 기준
---------

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - 검증 수준
     - 정상 완료 기준
   * - b. 노드 상태
     - Kubernetes 노드 3개 모두 Ready
   * - c. 배포 상태
     - 시스템 파드 정상 실행
   * - d. 서비스 동작
     - 파드 간 통신, DNS, ClusterIP 접근 성공
   * - e. 클라우드 연동
     - providerID와 OpenStack 서버 ID 일치

참고 문서
---------

* `Calico Documentation
  <https://docs.tigera.io/calico/latest/>`_
* `CAPO External Cloud Provider
  <https://cluster-api-openstack.sigs.k8s.io/topics/external-cloud-provider>`_
* `Cloud Provider OpenStack
  <https://github.com/kubernetes/cloud-provider-openstack>`_
