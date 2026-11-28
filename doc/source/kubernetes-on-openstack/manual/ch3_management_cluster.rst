3단계. kind 관리 클러스터와 Cluster API 설치
============================================

이 단계에서는 Docker 위에 kind 관리 클러스터를 생성하고,
Cluster API와 CAPO를 설치합니다.

kind는 Docker 컨테이너를 Kubernetes 노드로 사용하여
Kubernetes 클러스터를 생성하는 도구입니다.

Cluster API는 Kubernetes 클러스터의 생성, 변경 및 삭제를
Kubernetes 리소스로 관리하는 프로젝트입니다.

CAPO(Cluster API Provider OpenStack)는 Cluster API가
OpenStack의 가상 머신과 네트워크 자원을 관리할 수 있도록
연결하는 인프라 프로바이더입니다.

.. note::

   이 단계에서는 실제 워크로드용 가상 머신을 생성하지 않습니다.
   워크로드 클러스터는 4단계에서 생성합니다.

사전 조건
---------

* 2단계 완료
* Docker 실행 중
* OpenStack API 접근 가능
* kubectl 설치
* 외부 컨테이너 레지스트리 접근 가능

도구 설치
---------

kind와 clusterctl을 다운로드합니다.

.. code-block:: bash

   mkdir -p ~/bin-dl
   cd ~/bin-dl

   curl -fsSLo kind \
       https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64

   CAPI_URL=https://github.com/kubernetes-sigs/cluster-api

   curl -fsSLo clusterctl \
       "$CAPI_URL/releases/download/v1.14.3/clusterctl-linux-amd64"

   chmod +x kind clusterctl

다운로드한 도구의 버전을 확인합니다.

.. code-block:: bash

   ./kind version
   ./clusterctl version -o short

기존 설치 파일이 없는지 확인한 뒤 시스템 경로에 설치합니다.

.. code-block:: bash

   for tool in kind clusterctl; do
       if [ -e "/usr/local/bin/$tool" ]; then
           echo "$tool already exists"
       else
           sudo install -m 0755 "$tool" "/usr/local/bin/$tool"
       fi
   done

   hash -r
   kind version
   clusterctl version -o short

Docker 접근 권한 설정
---------------------

일반 사용자 계정에서 Docker를 실행할 수 있는지 확인합니다.

.. code-block:: bash

   docker ps

권한 오류가 발생하는 경우, 전용 실습 계정에 Docker
그룹 권한을 추가합니다.

.. code-block:: bash

   sudo usermod -aG docker "$USER"

SSH 연결을 종료하고 새로 접속한 뒤 확인합니다.

.. code-block:: bash

   id -nG
   docker ps

.. warning::

   Docker 그룹은 사실상 관리자 수준의 권한을 제공합니다.
   신뢰할 수 있는 실습 계정에만 권한을 부여합니다.

   기존 tmux 세션에서는 이전 그룹 권한이 유지될 수
   있으므로 새 로그인 세션에서 실행합니다.

관리 클러스터 생성
------------------

이번 실습에서 사용한 kind 관리 클러스터의 Kubernetes
버전은 v1.36.4입니다.

Cluster API의 지원 범위를 고려하여 kind의 기본 이미지
대신 사용할 노드 이미지를 명시합니다.

.. code-block:: bash

   NODE_IMAGE=kindest/node:v1.36.4
   DIGEST=099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed

   time kind create cluster --name mgmt \
       --image "$NODE_IMAGE@sha256:$DIGEST"

클러스터 상태를 확인합니다.

.. code-block:: bash

   kind get clusters
   kubectl --context kind-mgmt get nodes

관리 클러스터의 네트워크 확인
------------------------------

Kolla-Ansible이 관리하는 Docker 환경에서는 Docker의
iptables 자동 설정이 비활성화되어 있을 수 있습니다.

이 경우 kind 관리 클러스터에서 외부 컨테이너 이미지를
다운로드하지 못할 수 있습니다.

먼저 kind 네트워크 대역을 확인합니다.

.. code-block:: bash

   docker network inspect kind

이번 실습에서는 172.17.0.0/16 대역을 사용했습니다.

.. warning::

   네트워크 대역과 외부 인터페이스 이름은 실제 서버에서
   확인한 값으로 설정해야 합니다.

   다음 명령어는 호스트 방화벽을 변경하므로 전용 실습
   환경에서만 진행합니다.

외부 통신에 필요한 NAT 규칙을 추가합니다.

.. code-block:: bash

   KIND_CIDR=172.17.0.0/16

   sudo iptables -t nat -C POSTROUTING \
       -s "$KIND_CIDR" -o eth0 -j MASQUERADE 2>/dev/null || \
   sudo iptables -t nat -A POSTROUTING \
       -s "$KIND_CIDR" -o eth0 -j MASQUERADE

관리 클러스터에서 OpenStack API 접근을 확인합니다.

.. code-block:: bash

   docker exec mgmt-control-plane curl \
       -s -o /dev/null -w '%{http_code}\n' \
       http://10.10.10.254:5000/v3

외부 레지스트리 접근을 확인합니다.

.. code-block:: bash

   for url in \
       https://quay.io/v2/ \
       https://registry.k8s.io/v2/ \
       https://ghcr.io/v2/ \
       https://registry-1.docker.io/v2/
   do
       echo "$url"
       docker exec mgmt-control-plane curl \
           -s -o /dev/null -m 10 \
           -w '%{http_code}\n' "$url"
   done

OpenStack API는 HTTP 200, 이미지 레지스트리는 HTTP 401
응답을 확인했습니다.

Cluster API 및 CAPO 설치
------------------------

clusterctl을 사용하여 Cluster API와 OpenStack
인프라 프로바이더를 설치합니다.

.. code-block:: bash

   time clusterctl init \
       --kubeconfig-context kind-mgmt \
       --core cluster-api:v1.14.3 \
       --bootstrap kubeadm:v1.14.3 \
       --control-plane kubeadm:v1.14.3 \
       --infrastructure openstack:v0.15.1

설치 과정에서 필요한 cert-manager도 함께 설치됩니다.

.. important::

   CAPO v0.15.1은 ORC가 설치되지 않은 상태에서
   잠시 Running으로 표시된 후 종료된 사례가 있습니다.

   ORC는 다음 단계에서 설치하며, CAPO의 지속적인 정상
   동작 여부도 4단계에서 다시 확인합니다.

NAT 규칙 영속화
---------------

서버 시작 시 kind 네트워크의 NAT 설정도 복원할 수 있도록
1단계에서 만든 스크립트를 수정합니다.

기존 파일을 백업합니다.

.. code-block:: bash

   sudo cp -p /usr/local/sbin/kolla-host-net.sh \
       /usr/local/sbin/kolla-host-net.sh.bak-before-kind

   sudo nano /usr/local/sbin/kolla-host-net.sh

스크립트 마지막에 다음 내용을 추가합니다.

.. code-block:: bash

   $IPT -t nat -C POSTROUTING -s 172.17.0.0/16 \
       -o eth0 -j MASQUERADE 2>/dev/null || \
       $IPT -t nat -A POSTROUTING -s 172.17.0.0/16 \
       -o eth0 -j MASQUERADE

스크립트 문법과 실행 결과를 확인합니다.

.. code-block:: bash

   sudo bash -n /usr/local/sbin/kolla-host-net.sh
   sudo /usr/local/sbin/kolla-host-net.sh
   sudo iptables -t nat -S POSTROUTING

설치 결과 확인
--------------

.. code-block:: bash

   kubectl --context kind-mgmt get nodes
   kubectl --context kind-mgmt get pods -A

   kubectl --context kind-mgmt get crd -o name \
       | grep -iE 'openstack|orc'

   docker ps --filter name=mgmt

완료 기준
---------

* 관리 클러스터 노드 Ready
* 관리 클러스터 Kubernetes v1.36.4
* Cluster API 컨트롤러 설치 완료
* CAPO 컨트롤러 및 관련 CRD 설치 완료
* 관리 클러스터에서 OpenStack API 접근 가능
* 관리 클러스터에서 외부 레지스트리 접근 가능

CAPO 컨트롤러의 최종 정상 동작은 ORC 설치 이후
4단계에서 확인합니다.

문제 해결
---------

Docker permission denied
~~~~~~~~~~~~~~~~~~~~~~~~

Docker 그룹 권한이 현재 로그인 세션에 적용되지 않은
경우 발생할 수 있습니다.

새 SSH 세션에서 docker ps 명령어를 다시 실행합니다.

cert-manager 이미지 다운로드 실패
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

clusterctl init이 context deadline exceeded 오류로
실패하는 경우 관리 클러스터의 외부 네트워크 연결과
NAT 규칙을 확인합니다.

참고 문서
---------

* `kind <https://kind.sigs.k8s.io/>`_
* `Cluster API <https://cluster-api.sigs.k8s.io/>`_
* `CAPO <https://cluster-api-openstack.sigs.k8s.io/>`_
