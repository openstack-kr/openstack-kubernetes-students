문제 해결 가이드
================

이 문서는 Kubernetes on OpenStack 수동 구축 과정에서
실제로 발생한 문제와 해결 방법을 정리한 것입니다.

오류가 발생한 경우 전체 구축을 처음부터 다시 진행하기보다
현재 단계의 로그와 오류 메시지를 확인하여 원인을 찾습니다.

Kolla-Ansible 관련 문제
-----------------------

passwords file missing
~~~~~~~~~~~~~~~~~~~~~~

**증상**

kolla-genpwd 실행 시 비밀번호 파일이 존재하지 않는다는
오류가 발생합니다.

**원인**

Kolla-Ansible 기본 설정 파일을 /etc/kolla 디렉터리에
복사하지 않은 경우 발생합니다.

**해결 방법**

0단계의 설정 파일 복사 작업을 확인한 뒤
kolla-genpwd를 다시 실행합니다.

Docker Python 모듈 누락
~~~~~~~~~~~~~~~~~~~~~~~

**증상**

Kolla-Ansible prechecks 과정에서 Docker Python 모듈을
찾을 수 없다는 오류가 발생합니다.

**해결 방법**

.. code-block:: bash

   source ~/kolla-venv/bin/activate
   pip install docker dbus-python

호스트 이름 해석 오류
~~~~~~~~~~~~~~~~~~~~~

**증상**

.. code-block:: text

   Hostname has to resolve uniquely to the IP address
   of api_interface

**원인**

호스트 이름이 여러 IP 주소로 해석되거나 localhost를
호스트 이름으로 사용한 경우 발생할 수 있습니다.

**확인 방법**

.. code-block:: bash

   hostname
   getent ahostsv4 "$(hostname)"
   cat /etc/hosts

**해결 방법**

호스트 이름과 인벤토리를 일치시키고 호스트 이름이
OpenStack 관리 IP로 고유하게 해석되도록 수정합니다.

MariaDB 포트 충돌
~~~~~~~~~~~~~~~~~

**증상**

MariaDB 컨테이너가 종료되며 다음 오류가 발생합니다.

.. code-block:: text

   Address already in use

**원인**

이번 실습에서는 ProxySQL과 MariaDB가 관리 VIP의
3306 포트를 사용하면서 충돌했습니다.

**확인 방법**

.. code-block:: bash

   sudo ss -ltnp | grep ':3306'
   sudo docker ps -a
   sudo docker logs mariadb

**해결 방법**

globals.yml에서 ProxySQL을 비활성화합니다.

.. code-block:: yaml

   enable_proxysql: "no"

기존 충돌 컨테이너의 상태와 삭제 영향을 확인한 뒤
필요한 정리 작업을 수행하고 Kolla-Ansible 배포를
다시 실행합니다.

OpenStack CLI 설정 파일 오류
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**증상**

.. code-block:: text

   Could not read clouds.yaml configuration file

**원인**

이번 실습에서는 openstacksdk 4.23.0 패키지에
필요한 defaults.json 파일이 누락된 것이 원인이었습니다.

**해결 방법**

.. code-block:: bash

   source ~/kolla-venv/bin/activate
   pip install 'openstacksdk==4.22.0'
   pip check

이미지 빌드 및 Terraform 관련 문제
----------------------------------

KVM 접근 권한 부족
~~~~~~~~~~~~~~~~~~

**증상**

이미지 빌드에 필요한 /dev/kvm 장치에 접근할 수 없습니다.

**확인 방법**

.. code-block:: bash

   ls -l /dev/kvm
   test -r /dev/kvm && test -w /dev/kvm && echo "KVM OK"

**해결 방법**

필요한 경우 실행 사용자에게 접근 권한을 부여합니다.

.. code-block:: bash

   sudo setfacl -m "u:$USER:rw" /dev/kvm

기존 장치의 그룹 소유자를 임의로 변경하지 않습니다.

Terraform apply가 멈춘 것처럼 보이는 문제
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**원인**

terraform apply의 출력을 tail 명령어로 전달하는 경우
승인 질문이 사용자에게 표시되지 않을 수 있습니다.

**해결 방법**

출력 파이프를 사용하지 않고 실행합니다.

.. code-block:: bash

   terraform apply

가상 머신 생성 실패
~~~~~~~~~~~~~~~~~~~

**증상**

.. code-block:: text

   Exceeded maximum number of retries

nova-compute 로그에서 다음 오류가 함께 발생했습니다.

.. code-block:: text

   Unable to open file
   No such file or directory

**원인**

호스트의 virtlogd 및 virtlockd 서비스와
nova_libvirt 컨테이너 사이의 충돌로 추정했습니다.

**해결 방법**

기존 가상 머신에 미치는 영향을 확인한 뒤 호스트의
virtlogd와 virtlockd 서비스를 중지하고
nova_libvirt 컨테이너를 재시작합니다.

.. code-block:: bash

   sudo docker restart nova_libvirt

실패한 가상 머신을 확인하고 다시 생성합니다.

.. note::

   위 조치 이후 가상 머신 생성에 성공했지만,
   동일한 오류를 재현하여 원인을 확정하지는 않았습니다.

kind 및 Cluster API 관련 문제
-----------------------------

Docker 권한 오류
~~~~~~~~~~~~~~~~

**증상**

.. code-block:: text

   permission denied
   /var/run/docker.sock

**해결 방법**

Docker 그룹 권한을 확인하고 새 SSH 로그인
세션에서 실행합니다.

.. code-block:: bash

   id -nG
   docker ps

컨테이너 이미지 다운로드 실패
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**증상**

clusterctl init 실행 중 cert-manager 이미지 다운로드가
실패하거나 다음 오류가 발생합니다.

.. code-block:: text

   context deadline exceeded

**원인**

이번 실습에서는 Docker의 iptables 설정이 비활성화되어
kind 컨테이너의 외부 통신에 필요한 NAT 규칙이
생성되지 않았습니다.

**확인 방법**

.. code-block:: bash

   docker network inspect kind
   sudo iptables -t nat -S POSTROUTING

   kubectl --context kind-mgmt \
       -n cert-manager get pods

**해결 방법**

3단계의 kind NAT 규칙을 확인하고 실제 네트워크 대역에
맞게 설정합니다.

원인을 해결한 뒤 clusterctl init을 다시 실행합니다.

CAPO webhook 연결 실패
~~~~~~~~~~~~~~~~~~~~~~

**증상**

.. code-block:: text

   connection refused
   CrashLoopBackOff

**원인**

CAPO v0.15.1이 사용하는 ORC 관련 CRD가 설치되지
않은 상태에서 컨트롤러가 반복 종료되었습니다.

**해결 방법**

4단계의 ORC 설치 절차를 수행하고 CAPO 컨트롤러를
재시작합니다.

.. code-block:: bash

   kubectl --context kind-mgmt rollout restart \
       deployment/capo-controller-manager -n capo-system

   kubectl --context kind-mgmt get pods -n capo-system

워커 노드 생성 지연
~~~~~~~~~~~~~~~~~~~

**증상**

KubeadmControlPlane이 초기화되지 않고 워커 머신이
Pending 상태로 유지됩니다.

**원인**

이번 실습에서는 호스트의 방화벽 규칙이 kind 관리
클러스터에서 워크로드 API 서버로 전달되는 패킷을
차단했습니다.

**확인 방법**

.. code-block:: bash

   sudo iptables -S FORWARD

**해결 방법**

4단계의 FORWARD 허용 규칙을 확인합니다.

FORWARD 기본 정책이 ACCEPT이더라도 연결된 하위
방화벽 체인에서 패킷을 차단할 수 있으므로 전체
규칙을 확인해야 합니다.

Calico 및 OCCM 관련 문제
------------------------

OCCM 반복 종료
~~~~~~~~~~~~~~

**증상**

.. code-block:: text

   Failed to create an OpenStack LoadBalancer client
   No suitable endpoint could be found in the service catalog

**원인**

Octavia가 구성되지 않은 환경에서 OCCM의 LoadBalancer
기능이 활성화되어 있었습니다.

**해결 방법**

cloud.conf에 다음 내용을 설정합니다.

.. code-block:: ini

   [LoadBalancer]
   enabled=false

안전하게 준비한 cloud.conf 파일로 기존 Secret을 갱신합니다.

.. code-block:: bash

   export KUBECONFIG=~/capi/k8s-lab.kubeconfig

   kubectl -n kube-system create secret generic cloud-config \
       --from-file=cloud.conf \
       --dry-run=client -o yaml | kubectl apply -f -

   kubectl -n kube-system rollout restart \
       ds/openstack-cloud-controller-manager

Secret 갱신 이후 임시 cloud.conf 파일은 삭제합니다.

Calico 노드 초기화 실패
~~~~~~~~~~~~~~~~~~~~~~~

**증상**

Calico 노드 파드가 정상적으로 시작되지 않으며
BIRD 관련 오류가 발생합니다.

**원인**

OpenStack 보안 그룹에서 Calico Typha가 사용하는
TCP 5473 포트의 접근을 허용하지 않았습니다.

**해결 방법**

5단계의 Calico Typha 통신 허용 절차에 따라
워커 보안 그룹에 필요한 규칙을 추가합니다.

확인 명령어는 다음과 같습니다.

.. code-block:: bash

   kubectl get tigerastatus
   kubectl -n calico-system get pods
   kubectl get nodes

클러스터 삭제 관련 문제
-----------------------

삭제 이후 네트워크 포트가 남는 경우
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

클러스터를 삭제하더라도 Terraform이 생성한 네트워크와
라우터에 필요한 포트는 남아 있어야 합니다.

따라서 남은 포트의 개수만으로 삭제 실패를 판단하지
않습니다.

.. code-block:: bash

   openstack port list

삭제 전후의 포트 이름과 ID를 비교하여 CAPO가 생성한
포트만 삭제되었는지 확인합니다.

명령어 실행 대상 혼동
---------------------

OpenStack CLI와 관리 클러스터, 워크로드 클러스터는
서로 다른 인증 환경을 사용합니다.

OpenStack 명령어가 실행되지 않는 경우 Kolla-Ansible
가상환경과 인증 설정을 확인합니다.

.. code-block:: bash

   source ~/kolla-venv/bin/activate
   source /etc/kolla/admin-openrc.sh

관리 클러스터를 조회하려면 다음 명령어를 사용합니다.

.. code-block:: bash

   unset KUBECONFIG
   kubectl --context kind-mgmt get nodes

워크로드 클러스터를 조회하려면 다음 명령어를 사용합니다.

.. code-block:: bash

   kubectl --kubeconfig ~/capi/k8s-lab.kubeconfig get nodes

.. warning::

   특히 리소스 삭제 명령을 실행하기 전에는 반드시
   현재 클러스터와 네임스페이스를 확인합니다.
