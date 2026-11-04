4단계. OpenStack 배포 전 준비
==========================================================================================

이 단계의 목표와 실행 위치
------------------------------------------------------------------------------------------

Ubuntu 호스트에서 OpenStack을 설치할 공간, 실행할 노드, 데이터를 저장할 방법을 준비합니다.
네임스페이스는 Kubernetes 자원을 이름과 관리 범위로 나누는 단위입니다.
레이블은 자원에 붙이는 이름표이며, 이 실습에서는 서비스를 어느 노드에 배치할지 결정할 때 사용합니다.
스토리지는 데이터 저장 공간입니다. 이 단계는 OpenStack 자체를 설치하기 전 준비 작업입니다.


OpenStack을 배포할 네임스페이스, 노드 레이블, 스토리지를 준비했습니다.
호스트의 ``kubectl`` 이 실습 클러스터에 연결되는지 ``kubectl get nodes`` 로 먼저 확인합니다.
팀은 ``cp`` 의 관리자 kubeconfig를 사용했고 파일 권한을 ``600`` 으로 제한했습니다.

호스트에서 클러스터에 연결하기
------------------------------------------------------------------------------------------

kubeconfig는 kubectl이 어느 클러스터에 어떤 인증 정보로 접속할지 알려 주는 파일입니다.
``KUBECONFIG`` 환경변수는 사용할 파일 경로를 지정합니다.
환경변수는 현재 터미널 세션에 적용되므로 새 터미널에서는 다시 설정해야 합니다.
실습용 kubeconfig를 별도 파일로 받습니다. Kubernetes API에 접근할 수 있는 관리자 설정이므로 공유하지 마세요.

.. code-block:: bash

   mkdir -p ~/.kube
   export KUBECONFIG="$HOME/.kube/openinfra-lab.conf"
   (umask 077; ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 'sudo cat /etc/kubernetes/admin.conf' > "$KUBECONFIG")
   kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'; echo
   kubectl get nodes

주소가 ``127.0.0.1`` 로 나오면 호스트 자신을 가리킵니다. API 서버 인증서가
``192.168.100.10`` 을 포함하는 실습 구성에서 아래처럼 변경한 뒤 다시 확인합니다.

.. code-block:: bash

   cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
   kubectl config set-cluster "$cluster" --server=https://192.168.100.10:6443
   kubectl get nodes

네 대가 ``Ready`` 이면 다음으로 넘어갑니다. 새 터미널을 열면 ``KUBECONFIG`` 를 같은 경로로 다시 설정합니다.

노드 역할과 차트 준비
------------------------------------------------------------------------------------------

.. code-block:: bash

   kubectl create namespace openstack
   kubectl label --overwrite node ctrl-worker openstack-control-plane=enabled openvswitch=enabled
   kubectl label --overwrite node compute-1 compute-2 openstack-compute-node=enabled openvswitch=enabled
   kubectl get nodes -L openstack-control-plane,openstack-compute-node,openvswitch

``ctrl-worker`` 에는 제어 서비스를, 두 컴퓨트 노드에는 Nova 컴퓨트 서비스를 배치합니다.
Open vSwitch는 세 워커에 모두 필요합니다.

.. code-block:: bash

   helm repo add openstack-helm https://tarballs.opendev.org/openstack/openstack-helm
   helm repo update
   helm plugin install https://opendev.org/openstack/openstack-helm-plugin
   git clone --branch 2026.1.0 --depth 1 https://opendev.org/openstack/openstack-helm.git ~/openstack-helm
   git -C ~/openstack-helm rev-parse HEAD
   helm plugin list

차트는 OpenStack-Helm 태그 ``2026.1.0`` 의 커밋 ``c665eedfa`` 에 맞췄습니다.
OpenStack 릴리스 이름과 개별 Helm 차트의 버전은 서로 다릅니다. :doc:`appendix_versions` 에 실제 설치 버전을 정리했습니다.

스토리지 확인
------------------------------------------------------------------------------------------

Kubespray 인벤토리의 ``group_vars/k8s_cluster/addons.yml`` 에 다음 값을 설정한 뒤 3단계 플레이북을 다시 실행했습니다.

.. code-block:: yaml

   local_path_provisioner_enabled: true
   local_path_provisioner_storage_class: "general"

.. code-block:: bash

   kubectl get storageclass
   kubectl get pods -A | grep local-path

``general`` 의 프로비저너는 ``rancher.io/local-path``, 회수 정책은 ``Delete``,
바인딩 모드는 ``WaitForFirstConsumer`` 였습니다. 1 GiB PVC를 만들고 ``ctrl-worker`` 에 배치한
테스트 파드에서 파일을 쓴 뒤 읽었을 때 ``storage-ok`` 가 출력됐습니다. 확인 후 테스트 파드와 PVC를 정리했습니다.
이 구성에서는 볼륨 데이터가 해당 노드의 로컬 디스크에 저장됩니다.


저장소 용어 읽기
------------------------------------------------------------------------------------------

StorageClass는 저장 공간을 제공하는 방식과 정책을 정의합니다.
PVC는 Pod가 사용할 저장 공간을 요청하는 Kubernetes 자원입니다.
프로비저너는 요청에 맞춰 저장 공간을 준비하는 프로그램입니다.
``WaitForFirstConsumer`` 는 사용할 Pod의 배치가 결정될 때까지 볼륨 연결을 기다리는 설정입니다.
따라서 PVC가 처음부터 Pending이라고 해서 바로 실패로 판단하지 않습니다.
회수 정책이 ``Delete`` 이면 PVC를 지울 때 연결된 저장 공간도 삭제될 수 있으므로,
시험 자원과 실제 서비스 자원을 구분해야 합니다.

직접 볼륨에 쓰고 읽어 보기
------------------------------------------------------------------------------------------

YAML에서는 들여쓰기가 구조를 나타냅니다. 아래 내용을 터미널 명령으로 실행하지 말고
파일에 저장한 뒤 ``kubectl apply -f`` 로 적용합니다. ``---`` 는 한 파일 안의 자원을 구분합니다.
아래는 팀의 1 GiB 시험을 따라 할 수 있게 만든 예시입니다. 호스트에서 ``sc-test.yaml`` 로 저장합니다.

.. code-block:: yaml

   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: sc-test
     namespace: openstack
   spec:
     storageClassName: general
     accessModes: [ReadWriteOnce]
     resources:
       requests:
         storage: 1Gi
   ---
   apiVersion: v1
   kind: Pod
   metadata:
     name: sc-test
     namespace: openstack
   spec:
     restartPolicy: Never
     nodeSelector:
       kubernetes.io/hostname: ctrl-worker
     containers:
     - name: check
       image: busybox:1.36
       command: ["sh", "-ec", "echo storage-ok > /data/check && cat /data/check"]
       volumeMounts:
       - name: data
         mountPath: /data
     volumes:
     - name: data
       persistentVolumeClaim:
         claimName: sc-test

.. code-block:: bash

   kubectl apply -f sc-test.yaml
   kubectl -n openstack get pods,pvc
   kubectl -n openstack logs sc-test

파드가 종료된 뒤 로그에 ``storage-ok`` 가 나오면 성공입니다. 이 예시로 만든 테스트 자원만
``kubectl delete -f sc-test.yaml`` 로 정리합니다.

Ingress 컨트롤러는 5단계에서 설치했습니다. 이번 실습에서는 MetalLB와 Gateway API를 설치하지 않았습니다.