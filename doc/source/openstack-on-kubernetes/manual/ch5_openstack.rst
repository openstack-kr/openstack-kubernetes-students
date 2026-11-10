5단계. Helm으로 OpenStack 배포하기
==========================================================================================

이 단계의 목표와 실행 위치
------------------------------------------------------------------------------------------

Ubuntu 호스트에서 OpenStack 서비스를 Kubernetes에 설치합니다.
Helm 차트는 설치할 자원과 기본 설정을 묶은 패키지이고, values는 실습 환경에 맞게
바꾸는 설정값입니다. 차트를 이름을 붙여 설치한 개별 배포를 릴리스라고 합니다.
이 장의 11개 릴리스는 제공된 수동 구축 기록 기준이며 자동화 키트와 구분합니다.


4단계에서 준비한 노드와 스토리지에 OpenStack을 배포했습니다. Helm 차트는 Kubernetes 리소스의 구성을 담고,
values 파일에는 이번 환경에 맞는 설정을 넣습니다. 팀은 차트를 하나씩 설치하고 파드 상태를 확인한 뒤 다음 차트로 넘어갔습니다.

설치 순서
------------------------------------------------------------------------------------------

#. ``rabbitmq`` → ``mariadb`` → ``memcached``. 서비스에서 사용할 메시지 큐, 데이터베이스, 캐시를 먼저 설치했습니다.
#. ``ingress-nginx`` → ``keystone`` → ``glance``. Ingress를 구성한 뒤 인증 서비스와 이미지 서비스를 설치했습니다.
#. ``openvswitch`` → ``libvirt`` → ``placement`` → ``nova`` → ``neutron``. 가상 스위치와 컴퓨트 서비스를 준비하고 네트워크 서비스를 연결했습니다.

차트별로 태그 ``2026.1.0`` 의 ``values_overrides`` 를 확인했습니다. 여덟 개 차트에는
``2026.1-ubuntu_noble.yaml`` 이 있었고, Open vSwitch에는 ``ubuntu_noble.yaml`` 을 사용했습니다.
Memcached에는 같은 이름의 파일이 없었습니다. 서버에는 릴리스별 설정 11개가
``openstack-helm/values-*.yaml`` 로 남아 있습니다. 차트별 설치 명령을 재현할 때는 이 파일과 실제 적용 순서를 함께 확인해야 합니다.


서비스를 나누어 설치하는 이유
------------------------------------------------------------------------------------------

RabbitMQ는 서비스 사이의 메시지를 전달하고, MariaDB는 데이터를 저장하며,
Memcached는 자주 사용하는 정보를 임시로 보관합니다.
Keystone은 인증, Glance는 VM 이미지, Nova는 컴퓨트 작업, Neutron은 네트워크를 담당합니다.
Placement는 사용할 컴퓨트 자원과 할당 정보를 관리합니다.
한 서비스가 다른 서비스에 의존하므로 순서와 준비 상태를 확인하면서 설치합니다.

이 단계에서 설치하는 Glance 이미지는 이후 OpenStack 사용자가 만들 VM의 운영체제 자료입니다.
서비스 컨테이너를 실행하는 이미지나 1단계 노드 VM의 클라우드 이미지와 구분합니다.

한 개씩 설치하기
------------------------------------------------------------------------------------------

아래는 팀의 최종 values를 가지고 새 실습 클러스터에 배포하는 방법입니다.
최종 values란 해당 릴리스에 실제로 적용한 사용자 설정 전체를 뜻합니다. 기본값이나 수정 전 초안만 있으면
스토리지 클래스·접속 경로·인증 설정이 달라질 수 있습니다. 기존 팀 클러스터에 접근할 수 있는 담당자는
``helm get values 릴리스이름 -n openstack -o yaml`` 로 해당 설정을 확인할 수 있습니다.
인증 정보를 포함할 수 있으므로 내보낸 파일은 비공개로 관리합니다.

호스트에서 최종 파일을 ``~/lab-values/values-rabbitmq.yaml`` 처럼 릴리스 이름별로 저장합니다.
Ingress 컨트롤러도 팀에서 실제 사용한 values가 필요합니다. 아래 예시는 실습 기록에 맞춘 명령 형식이며
실제 서버의 셸 기록을 그대로 옮긴 것은 아닙니다.

.. code-block:: bash

   export KUBECONFIG="$HOME/.kube/openinfra-lab.conf"
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update
   kubectl get nodes
   kubectl get storageclass general

아래 함수를 호스트의 Bash 터미널에 한 번 입력합니다.
먼저 차트와 설정 파일로 매니페스트를 생성해 문법을 확인한 뒤에만 설치합니다.

.. code-block:: bash

   deploy_chart() {
     local name="$1" version="$2" chart="openstack-helm/$1"
     local values="$HOME/lab-values/values-$1.yaml"
     [ "$name" != ingress-nginx ] || chart=ingress-nginx/ingress-nginx
     [ -s "$values" ] || { echo "설정 파일을 확인하세요: $values"; return 1; }
     helm template "$name" "$chart" -n openstack --version "$version" -f "$values" >/dev/null || return 1
     helm upgrade --install "$name" "$chart" -n openstack --version "$version" -f "$values" --timeout 15m
   }

다음은 **한 줄씩** 실행합니다. 매번 ``helm status 릴리스이름 -n openstack`` 과
``kubectl get pods,jobs -n openstack`` 로 결과를 보세요. RabbitMQ와 MariaDB는 파드가 준비된 뒤 다음으로 넘어갑니다.
``failed`` 가 나오면 아래의 해당 서비스 설명을 먼저 확인하세요.
libvirt와 Nova는 Neutron이 준비될 때까지 일부 파드가 대기할 수 있습니다.

.. code-block:: bash

   deploy_chart rabbitmq 2025.2.11+c665eedfa
   deploy_chart mariadb 2025.2.9+c665eedfa
   deploy_chart memcached 2025.2.6+c665eedfa
   deploy_chart ingress-nginx 4.8.3
   deploy_chart keystone 2025.2.18+c665eedfa
   deploy_chart glance 2025.2.19+c665eedfa
   deploy_chart openvswitch 2025.2.11+c665eedfa
   deploy_chart libvirt 2025.2.13+c665eedfa
   deploy_chart placement 2025.2.16+c665eedfa
   deploy_chart nova 2025.2.34+c665eedfa
   deploy_chart neutron 2025.2.30+c665eedfa

차트를 찾을 수 없으면 ``helm search repo openstack-helm/rabbitmq --versions`` 처럼
버전을 조회하세요. 같은 릴리스의 차트 패키지가 팀에 보관돼 있으면 해당 패키지를 사용합니다.
공식 문서의 배포 예시는 버전에 따라 달라질 수 있습니다. 이 기록은 고정한 차트 버전에서
Ingress를 사용했으므로 다른 버전이나 접속 방식의 설정을 그대로 섞지 않습니다.
참고 문서는 `OpenStack-Helm 배포 가이드 <https://docs.openstack.org/openstack-helm/latest/install/openstack.html>`_ 입니다.


배포 명령의 의미
------------------------------------------------------------------------------------------

``deploy_chart`` 는 반복되는 Helm 명령을 묶은 Bash 함수입니다.
같은 터미널에서 함수 정의를 먼저 입력한 뒤 서비스별 호출을 실행합니다.
``helm template`` 는 적용할 설정을 Kubernetes 매니페스트로 만드는지 확인합니다.
매니페스트는 Kubernetes에 생성할 자원을 적은 설정 문서입니다.
렌더링이 성공해도 이미지 다운로드나 서비스 시작까지 성공한 것은 아닙니다.

``helm upgrade --install`` 은 같은 릴리스가 있으면 갱신하고 없으면 설치합니다.
이 예시에는 ``--wait`` 가 없으므로 명령 종료 후 Pod가 준비됐는지 별도로 확인합니다.
``--timeout`` 만으로 모든 Pod의 준비 완료를 기다린다고 해석하지 않습니다.

실제로 바꾼 설정
------------------------------------------------------------------------------------------

* **Ingress** — Keystone 이름으로 접속했을 때 HTTP 404가 발생했습니다. 차트가 만든 Ingress의 클래스는
  ``ingress-openstack`` 이었지만 컨트롤러는 ``nginx`` 를 처리하고 있었습니다.
  컨트롤러의 클래스를 맞춘 뒤 이름을 통한 접속에 성공했습니다.
* **DNS** — 가상 네트워크의 DHCP 검색 도메인 ``lab.local`` 이 파드까지 전달되면서 일부 이름이 잘못된 주소로 해석됐습니다.
  각 VM에서 ``UseDomains=false`` 로 바꾼 뒤 이름 해석을 다시 확인했습니다.
* **Glance** — 초기 이미지 CirrOS 다운로드가 134초 뒤 시간 초과로 실패했습니다. ``bootstrap.enabled=false`` 로
  초기 이미지 다운로드를 끄고 다시 배포했습니다. 실제 이미지 등록은 :doc:`ch6_verify` 에서 따로 확인했습니다.
* **libvirt와 Nova** — Ceph를 사용하지 않아 두 차트에 ``conf.ceph.enabled=false`` 를 지정했습니다.
  Nova에는 ``conf.nova.libvirt.virt_type=qemu`` 를 설정한 뒤 ``nova.conf`` 에서 적용 여부를 확인했습니다.
* **Neutron** — 컴퓨트 노드의 NIC는 한 개였습니다. 이번 실습에서는 외부 네트워크 브리지 ``br-ex`` 를 구성하지 않았습니다.

배포 확인
------------------------------------------------------------------------------------------

.. code-block:: bash

   helm list -n openstack --all
   kubectl get pods -n openstack -o wide
   kubectl get ingress -n openstack

Neutron 설치 전에는 libvirt와 nova-compute 파드가 ``Init`` 에서 대기했습니다.
이때 ``helm osh wait-for-pods`` 로 전체 파드를 기다리면 설치가 진행되지 않아 해당 릴리스의 상태만 확인했습니다.
Neutron 설치 후 두 컴퓨트 노드에서 libvirt와 nova-compute가 각각 ``1/1 Running`` 이 됐습니다.
11월 1일 22시 34분 기준으로 릴리스 11개가 모두 ``deployed`` 였습니다.

7단계에서 추가한 배포와 변경 사항
------------------------------------------------------------------------------------------

위의 11개는 11월 1일의 배포 기록입니다. 11월 3~4일에는 Horizon을
12번째 릴리스로 추가하고 Neutron VXLAN 포트를 4790으로 변경했습니다.
Neutron 리비전은 3이 되었으며 차트 버전과 리비전 번호는 서로 다릅니다.
최종 상태를 재현할 때는 초기 values뿐 아니라 두 변경의 최종 설정도 반영해야 합니다.
파일 목록은 :doc:`appendix_manual_refs`, 실습은 :doc:`ch7_horizon` 을 확인합니다.

11월 4일에는 DNS 수정 전에 만들어진 일부 API Pod가 옛 설정을 유지해
장애가 재발했습니다. 노드 설정 변경 후 기존 Pod 내부 설정도 확인해야 합니다.
이 사례와 조치 결과는 :doc:`ch8_troubleshooting` 에 정리했습니다.