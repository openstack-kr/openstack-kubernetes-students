1단계. Kolla-Ansible로 OpenStack 구축
=====================================

이 단계에서는 Kolla-Ansible을 이용하여 단일 서버에
OpenStack 2026.1 환경을 구축합니다.

구축이 완료되면 이후 단계에서 Terraform과 CAPO가
OpenStack API를 이용하여 인프라 자원을 관리할 수 있습니다.

사전 조건
---------

* 0단계 완료
* Kolla-Ansible 가상환경 사용 가능
* /dev/kvm 장치 존재
* 충분한 디스크 여유 공간
* 외부 이미지 저장소에 접근 가능

단일 NIC 네트워크 구성
----------------------

일반적인 OpenStack 구성에서는 관리 네트워크와 외부
네트워크를 위한 인터페이스를 구분합니다.

이번 실습 서버는 물리 네트워크 인터페이스가 하나이므로
dummy 인터페이스와 veth 인터페이스를 추가하여 구성합니다.

dummy 인터페이스는 물리 장치 없이 생성하는 가상
네트워크 인터페이스입니다.

veth는 두 개의 가상 인터페이스를 연결하여 한쪽에서
전송한 패킷을 다른 쪽으로 전달하는 가상 장치입니다.

.. list-table::
   :header-rows: 1
   :widths: 25 30 45

   * - 인터페이스
     - IP 주소
     - 역할
   * - eth0
     - 서버 기존 IP
     - SSH 접속 및 외부 통신
   * - kolla0
     - 10.10.10.254/24
     - OpenStack 관리 인터페이스
   * - veth-ext
     - 없음
     - Neutron 외부 네트워크 연결
   * - veth-host
     - 10.20.20.1/24
     - 외부망 게이트웨이

.. code-block:: text

   Internet
       |
      eth0
       |
   Host NAT
       |
   veth-host (10.20.20.1)
       |
   veth-ext
       |
      br-ex
       |
   OpenStack External Network

.. warning::

   다음 작업은 호스트의 네트워크 및 방화벽 설정을 변경합니다.
   전용 실습 서버인지 확인하고, 기존 설정을 백업한 뒤
   진행합니다. 원격 접속에 영향을 줄 수 있으므로 복구 가능한
   콘솔 접근 수단을 확보하는 것을 권장합니다.

네트워크 설정 스크립트 생성
~~~~~~~~~~~~~~~~~~~~~~~~~~~

다음 파일을 생성합니다.

.. code-block:: bash

   sudo nano /usr/local/sbin/kolla-host-net.sh

아래 내용을 작성합니다.

.. code-block:: bash

   #!/bin/bash
   set -eu

   IPT=/usr/sbin/iptables

   ip link show kolla0 >/dev/null 2>&1 || \
       ip link add kolla0 type dummy

   ip addr show dev kolla0 | grep -q '10.10.10.254/24' || \
       ip addr add 10.10.10.254/24 dev kolla0

   ip link set kolla0 up

   ip link show veth-ext >/dev/null 2>&1 || \
       ip link add veth-ext type veth peer name veth-host

   ip addr show dev veth-host | grep -q '10.20.20.1/24' || \
       ip addr add 10.20.20.1/24 dev veth-host

   ip link set veth-ext up
   ip link set veth-host up

   $IPT -C INPUT -i veth-host -j ACCEPT 2>/dev/null || \
       $IPT -I INPUT 1 -i veth-host -j ACCEPT

   $IPT -C INPUT -d 10.10.10.254/32 ! -i eth0 \
       -j ACCEPT 2>/dev/null || \
       $IPT -I INPUT 1 -d 10.10.10.254/32 ! -i eth0 \
       -j ACCEPT

   $IPT -C FORWARD -i veth-host -o eth0 \
       -j ACCEPT 2>/dev/null || \
       $IPT -I FORWARD 1 -i veth-host -o eth0 -j ACCEPT

   $IPT -C FORWARD -i eth0 -o veth-host \
       -m state --state RELATED,ESTABLISHED \
       -j ACCEPT 2>/dev/null || \
       $IPT -I FORWARD 2 -i eth0 -o veth-host \
       -m state --state RELATED,ESTABLISHED -j ACCEPT

   $IPT -t nat -C POSTROUTING -s 10.20.20.0/24 \
       -o eth0 -j MASQUERADE 2>/dev/null || \
       $IPT -t nat -A POSTROUTING -s 10.20.20.0/24 \
       -o eth0 -j MASQUERADE

스크립트 실행 권한을 설정합니다.

.. code-block:: bash

   sudo chmod 755 /usr/local/sbin/kolla-host-net.sh
   sudo bash -n /usr/local/sbin/kolla-host-net.sh

iptables의 -C 옵션은 동일한 규칙이 존재하는지 확인합니다.
이를 이용하여 스크립트를 다시 실행해도 동일한 방화벽
규칙이 중복되지 않도록 구성했습니다.

IP 포워딩 설정
~~~~~~~~~~~~~~

IP 포워딩은 서버가 서로 다른 네트워크 사이의 패킷을
전달할 수 있도록 하는 기능입니다.

.. code-block:: bash

   sudo nano /etc/sysctl.d/99-kolla-host.conf

다음 내용을 작성합니다.

.. code-block:: ini

   net.ipv4.ip_forward = 1

설정을 적용합니다.

.. code-block:: bash

   sudo sysctl -p /etc/sysctl.d/99-kolla-host.conf

네트워크 설정 영속화
~~~~~~~~~~~~~~~~~~~~

서버가 시작될 때 네트워크 설정 스크립트를 실행하도록
systemd 서비스를 생성합니다.

.. code-block:: bash

   sudo nano /etc/systemd/system/kolla-host-net.service

다음 내용을 작성합니다.

.. code-block:: ini

   [Unit]
   Description=Kolla single-NIC host network
   After=netfilter-persistent.service
   Before=docker.service

   [Service]
   Type=oneshot
   RemainAfterExit=yes
   ExecStart=/usr/local/sbin/kolla-host-net.sh

   [Install]
   WantedBy=multi-user.target

서비스를 등록하고 실행합니다.

.. code-block:: bash

   sudo systemctl daemon-reload
   sudo systemctl enable --now kolla-host-net.service

설정 결과를 확인합니다.

.. code-block:: bash

   systemctl status kolla-host-net.service
   ip -br addr
   sysctl net.ipv4.ip_forward
   sudo iptables -t nat -S POSTROUTING

.. note::

   스크립트 재실행 시 규칙이 중복되지 않는 것은 확인했습니다.
   서버 재부팅 이후 정상적으로 복원되는지는 시험하지 않았습니다.

OpenStack 설정 파일 수정
------------------------

Kolla-Ansible의 전체 배포 설정은 globals.yml 파일에서
관리합니다.

.. code-block:: bash

   cp /etc/kolla/globals.yml /etc/kolla/globals.yml.orig
   nano /etc/kolla/globals.yml

기존 설정 파일에서 다음 항목을 찾아 수정합니다.

.. code-block:: yaml

   kolla_base_distro: "ubuntu"
   openstack_release: "2026.1"
   kolla_internal_vip_address: "10.10.10.254"
   network_interface: "kolla0"
   neutron_external_interface: "veth-ext"
   enable_haproxy: "no"
   enable_proxysql: "no"

.. note::

   위 내용은 globals.yml 전체가 아닌 수정할 항목입니다.
   동일한 키가 중복되지 않도록 주의합니다.

이번 실습은 단일 서버 구성으로 진행하므로 HAProxy와
ProxySQL을 비활성화합니다.

ProxySQL이 활성화된 상태에서는 MariaDB와 동일한 포트를
사용하여 배포가 실패한 사례가 있었습니다.

호스트 이름 설정
----------------

호스트 이름은 localhost가 아닌 고유한 이름을 사용합니다.

이번 실습에서는 kolla-aio라는 이름을 사용합니다.

.. code-block:: bash

   sudo cp /etc/hosts /etc/hosts.bak-kolla
   cp ~/all-in-one ~/all-in-one.bak-kolla
   sudo hostnamectl set-hostname kolla-aio
   sudo nano /etc/hosts

기존 localhost 설정은 보존하고, kolla-aio가 관리 IP로
해석되도록 설정합니다.

.. code-block:: text

   127.0.0.1 localhost
   10.10.10.254 kolla-aio

기존 kolla-aio 관련 중복 항목이 있다면 정리합니다.

인벤토리의 localhost 호스트 항목을 변경합니다.

.. code-block:: bash

   sed -i 's/^localhost\b/kolla-aio/' ~/all-in-one

변경 결과를 확인합니다.

.. code-block:: bash

   hostname
   getent ahostsv4 kolla-aio
   grep -n kolla-aio ~/all-in-one

kolla-aio가 10.10.10.254로 해석되는지 확인합니다.

호스트 libvirt 충돌 방지
-------------------------------

Kolla-Ansible은 OpenStack 내부에서 nova_libvirt
컨테이너를 사용합니다.

호스트에 기존 libvirt 서비스가 실행 중이면 소켓이나
파일 접근 과정에서 충돌이 발생할 수 있습니다.

.. code-block:: bash

   systemctl list-units 'libvirt*'
   sudo virsh list --all

.. warning::

   기존 가상 머신이 없는 전용 실습 환경인지 확인합니다.
   운영 중인 가상 머신이 있다면 아래 명령어를 실행하지 않습니다.

호스트의 libvirt 관련 서비스와 소켓을 중지합니다.

.. code-block:: bash

   sudo systemctl disable --now \
       libvirtd.socket libvirtd-ro.socket \
       libvirtd-admin.socket libvirtd.service \
       libvirt-guests.service

   sudo systemctl disable --now \
       virtlogd.socket virtlogd-admin.socket \
       virtlockd.socket virtlockd-admin.socket \
       virtlogd.service virtlockd.service

.. note::

   virtlogd와 virtlockd의 중지 필요성은 실제 2단계에서
   발견되었습니다. 이 가이드에서는 해당 정정 내용을
   반영하여 1단계에 함께 배치했습니다.

   시스템에 설치되지 않은 유닛은 별도로 확인합니다.

Docker 및 호스트 환경 준비
--------------------------

Kolla-Ansible 가상환경을 활성화합니다.

.. code-block:: bash

   source ~/kolla-venv/bin/activate

Docker SDK 및 관련 Python 모듈을 설치합니다.

.. code-block:: bash

   pip install docker dbus-python

Kolla-Ansible의 bootstrap-servers 명령어를 이용하여
Docker와 호스트 실행 환경을 준비합니다.

.. code-block:: bash

   kolla-ansible bootstrap-servers -i ~/all-in-one

사전 점검
---------

OpenStack 배포에 필요한 설정과 실행 환경을 점검합니다.

.. code-block:: bash

   time kolla-ansible prechecks \
       -i ~/all-in-one --use-test-images

실습에서 사용한 Quay 이미지에 대한 사전 점검을 통과하기
위해 --use-test-images 옵션을 지정했습니다.

실행 결과의 PLAY RECAP에서 failed=0인지 확인합니다.

OpenStack 이미지 다운로드
-------------------------

OpenStack 서비스에 필요한 컨테이너 이미지를 받습니다.

.. code-block:: bash

   time kolla-ansible pull -i ~/all-in-one

OpenStack 배포
--------------

.. code-block:: bash

   time kolla-ansible deploy -i ~/all-in-one

배포가 정상적으로 완료되면 다음 작업을 수행합니다.

.. code-block:: bash

   time kolla-ansible post-deploy -i ~/all-in-one

.. important::

   --use-test-images 옵션은 이번 실습에서 prechecks에만
   사용했습니다. pull과 deploy에 추가하지 않습니다.

OpenStack CLI 설치
------------------

OpenStack 서비스를 명령어로 관리하기 위해
python-openstackclient를 설치합니다.

.. code-block:: bash

   pip install 'python-openstackclient==10.5.0'
   pip install 'openstacksdk==4.22.0'
   pip check

실습에서는 openstacksdk 4.23.0의 파일 누락 문제를
경험하여 4.22.0으로 고정했습니다.

OpenStack 인증 설정
-------------------

OpenStack API를 사용하기 위해 관리자 인증 환경을
불러옵니다.

.. code-block:: bash

   source /etc/kolla/admin-openrc.sh

.. warning::

   인증 정보를 불러온 뒤 env 또는 printenv 명령어를
   실행하여 전체 환경변수를 공개하지 않습니다.

서비스 상태 확인
----------------

.. code-block:: bash

   sudo docker ps
   openstack service list
   openstack compute service list
   openstack network agent list
   openstack hypervisor list

가상화 방식도 확인합니다.

.. code-block:: bash

   sudo grep -n '^virt_type' \
       /etc/kolla/nova-compute/nova.conf

완료 기준
---------

* Kolla-Ansible 배포 결과 failed=0
* OpenStack CLI 인증 및 서비스 조회 가능
* 컴퓨트 서비스가 enabled/up 상태
* 네트워크 에이전트가 정상 동작
* 하이퍼바이저가 up 상태
* virt_type이 kvm으로 설정됨

실제 실습 결과
--------------

.. list-table::
   :header-rows: 1

   * - 검증 항목
     - 관찰 결과
   * - 실행 중인 컨테이너
     - 33개
   * - 등록된 OpenStack 서비스
     - 7개
   * - 컴퓨트 서비스
     - 3개 정상
   * - 네트워크 에이전트
     - 4개 정상
   * - 하이퍼바이저
     - 1개 정상
   * - 가상화 방식
     - KVM

위 수치는 이번 실습 환경에서 관찰한 결과이며,
다른 설정에서는 컨테이너 및 서비스 개수가 달라질 수 있습니다.

참고 문서
---------

* `Kolla-Ansible Quick Start
  <https://docs.openstack.org/project-deploy-guide/kolla-ansible/2026.1/quickstart.html>`_
