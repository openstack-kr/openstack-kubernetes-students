6단계. 클러스터 삭제 및 자원 정리 검증
======================================

이 단계에서는 생성한 Kubernetes 워크로드 클러스터를
삭제하고 OpenStack 자원이 정상적으로 정리되는지 확인합니다.

클러스터를 삭제한 이후에도 Terraform이 구성한 공용
인프라 자원은 유지되어야 합니다.

이 검증을 통해 클러스터의 생명주기 관리와 인프라 자원
관리 범위가 올바르게 구분되는지 확인합니다.

자원 관리 주체
--------------

.. list-table::
   :header-rows: 1
   :widths: 25 45 30

   * - 관리 도구
     - 자원
     - 삭제 검증 결과
   * - CAPO
     - Kubernetes 노드 가상 머신
     - 삭제되어야 함
   * - CAPO
     - 가상 머신 네트워크 포트
     - 삭제되어야 함
   * - CAPO
     - API 서버 Floating IP
     - 삭제되어야 함
   * - CAPO
     - 클러스터 관리 보안 그룹
     - 삭제되어야 함
   * - Terraform
     - 외부 및 내부 네트워크
     - 유지되어야 함
   * - Terraform
     - 서브넷과 라우터
     - 유지되어야 함
   * - Terraform
     - Flavor, 키페어, 이미지
     - 유지되어야 함

.. warning::

   클러스터 삭제는 되돌릴 수 없는 작업입니다.

   필요한 데이터와 설정을 먼저 백업하고, 삭제 대상이
   실습용 클러스터인지 확인한 뒤 진행합니다.

   관리 클러스터는 자원 정리를 담당하므로 삭제 검증이
   완료될 때까지 유지합니다.

관리 클러스터 접근 확인
------------------------

워크로드 클러스터의 kubeconfig 환경변수를 해제합니다.

.. code-block:: bash

   unset KUBECONFIG

관리 클러스터의 클러스터 및 머신 정보를 확인합니다.

.. code-block:: bash

   kubectl --context kind-mgmt get \
       cluster,machine,openstackcluster,openstackmachine -A

삭제 대상은 default 네임스페이스의 k8s-lab 클러스터입니다.

삭제 전 OpenStack 상태 기록
----------------------------

삭제 전후 자원을 비교하기 위한 기록 디렉터리를 생성합니다.

.. code-block:: bash

   source ~/kolla-venv/bin/activate

   export OS_CLIENT_CONFIG_FILE=/etc/kolla/clouds.yaml
   export OS_CLOUD=kolla-admin-internal

   mkdir -p ~/capi/stage6
   cd ~/capi/stage6
   umask 077

삭제 전 OpenStack 자원을 파일로 기록합니다.

.. code-block:: bash

   {
       echo "=== Servers ==="
       openstack server list

       echo "=== Floating IPs ==="
       openstack floating ip list

       echo "=== Security Groups ==="
       openstack security group list

       echo "=== Ports ==="
       openstack port list

       echo "=== Networks ==="
       openstack network list

       echo "=== Subnets ==="
       openstack subnet list

       echo "=== Routers ==="
       openstack router list

       echo "=== Flavors ==="
       openstack flavor list

       echo "=== Keypairs ==="
       openstack keypair list

       echo "=== Images ==="
       openstack image list

   } > before-openstack.txt

워크로드 클러스터 삭제
----------------------

삭제 대상과 저장한 기록을 확인한 뒤 다음 명령어를
실행합니다.

.. code-block:: bash

   time kubectl --context kind-mgmt -n default \
       delete cluster k8s-lab --timeout=20m

CAPO가 클러스터와 연결된 OpenStack 자원을 정리합니다.

클러스터 삭제 결과 확인
------------------------

.. code-block:: bash

   kubectl --context kind-mgmt get \
       cluster,machine,openstackcluster,openstackmachine -A

관리 클러스터에 다른 워크로드가 없는 전용 실습 환경이라면
No resources found 메시지를 확인할 수 있습니다.

OpenStack 자원의 삭제 결과도 확인합니다.

.. code-block:: bash

   openstack server list
   openstack floating ip list
   openstack security group list
   openstack port list

CAPO가 생성한 가상 머신, Floating IP, 보안 그룹 및
관련 포트가 남아 있지 않은지 확인합니다.

삭제 후 OpenStack 상태 기록
----------------------------

.. code-block:: bash

   cd ~/capi/stage6

   {
       echo "=== Servers ==="
       openstack server list

       echo "=== Floating IPs ==="
       openstack floating ip list

       echo "=== Security Groups ==="
       openstack security group list

       echo "=== Ports ==="
       openstack port list

       echo "=== Networks ==="
       openstack network list

       echo "=== Subnets ==="
       openstack subnet list

       echo "=== Routers ==="
       openstack router list

       echo "=== Flavors ==="
       openstack flavor list

       echo "=== Keypairs ==="
       openstack keypair list

       echo "=== Images ==="
       openstack image list

   } > after-openstack.txt

삭제 전후 결과 비교
-------------------

.. code-block:: bash

   diff -u before-openstack.txt after-openstack.txt

삭제 전후 자원의 이름과 ID를 비교하여 CAPO 관리 자원만
삭제되었는지 확인합니다.

Terraform 공용 자원의 유지 여부도 확인합니다.

.. code-block:: bash

   source ~/kolla-venv/bin/activate
   source /etc/kolla/admin-openrc.sh

   cd ~/tf-common
   terraform plan

실제 실습에서 관찰된 자원 정리 결과
-----------------------------------

.. list-table::
   :header-rows: 1
   :widths: 30 20 20 30

   * - 자원
     - 삭제 전
     - 삭제 후
     - 판정
   * - 가상 머신
     - 3
     - 0
     - 정상 정리
   * - Floating IP
     - 1
     - 0
     - 정상 정리
   * - 보안 그룹
     - 4
     - 2
     - 기본 그룹 유지
   * - 네트워크 포트
     - 7
     - 3
     - 공용 포트 유지
   * - Cinder 볼륨
     - 0
     - 0
     - 변화 없음
   * - 네트워크
     - 2
     - 2
     - 유지
   * - 서브넷
     - 2
     - 2
     - 유지
   * - 라우터
     - 1
     - 1
     - 유지
   * - Flavor
     - 1
     - 1
     - 유지
   * - 키페어
     - 1
     - 1
     - 유지
   * - 이미지
     - 1
     - 1
     - 유지

삭제 후 남은 네트워크 포트는 DHCP, 라우터 내부
인터페이스 및 라우터 외부 게이트웨이 포트입니다.

따라서 포트의 개수가 0이 아니더라도 클러스터 관련
포트가 모두 삭제되었다면 정상입니다.

.. important::

   자원 개수만으로 삭제 결과를 판정하지 않습니다.
   반드시 자원의 이름, ID, 용도를 확인합니다.

남은 파일과 인증 정보 정리
---------------------------

클러스터를 삭제하더라도 호스트에 생성했던 kubeconfig
파일은 자동으로 삭제되지 않습니다.

다시 사용하지 않는 것을 확인한 뒤 삭제합니다.

.. code-block:: bash

   rm -v ~/capi/k8s-lab.kubeconfig

관리 클러스터의 인증 Secret도 자동으로 삭제되지
않았으므로 별도로 관리해야 합니다.

.. code-block:: bash

   kubectl --context kind-mgmt -n default \
       get secret k8s-lab-cloud-config

인증 Secret의 내용을 출력하지 않습니다.

재구축에 필요한 k8s-lab.yaml 파일은 보관합니다.

관리 클러스터 및 인증 Secret의 최종 삭제는
추가 실습 여부를 결정한 뒤 별도로 진행합니다.

완료 기준
---------

* CAPO가 생성한 가상 머신 3대 삭제
* 클러스터용 Floating IP 삭제
* CAPO 관리 보안 그룹 삭제
* 클러스터 관련 네트워크 포트 삭제
* Terraform 공용 기반 자원 유지
* 관리 클러스터 정상 동작

실습 결과와 한계
----------------

실제 실습에서 클러스터 삭제 명령은 약 36초 만에
종료되었습니다.

다만 OpenStack 자원의 최종 상태는 삭제 명령이 종료된
후 약 1시간 뒤에 확인했습니다.

따라서 36초를 전체 OpenStack 자원의 정리 완료
시간으로 해석하지 않습니다.

삭제 이후 동일한 설정으로 클러스터를 재생성하는
반복 구축 시험은 수행하지 않았습니다.

.. note::

   이번 단계에서는 Terraform 공용 자원과 OpenStack
   자체를 삭제하지 않습니다.

   terraform destroy 및 Kolla-Ansible 환경 전체 삭제는
   별도의 작업 범위에 해당합니다.
