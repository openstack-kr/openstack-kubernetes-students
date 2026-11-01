.. _infrastructure:

===============================================
인프라 구성 (1~2단계: VM 생성과 노드 사전 설정)
===============================================

이 장에서는 노드 VM 4대를 만들고(1단계), Kubernetes 를 설치할 수 있도록
각 노드를 준비합니다(2단계). 이 장이 끝나면 Kubespray 가 접속해 작업할 수 있는
노드 4대가 준비됩니다.

.. list-table::
   :widths: 15 85

   * - 목표
     - libvirt/KVM 으로 노드 VM 4대를 만들고, 노드를 Kubernetes 설치에 맞게 설정합니다.
   * - 사용 도구
     - Terraform (+ libvirt provider), Ansible
   * - 실행 명령
     - ``make stage-1`` (VM 생성), ``make stage-2`` (노드 사전 설정)
   * - 소요 시간
     - 1단계 ``terraform apply`` 약 1분 30초 (이 가이드의 서버 기준). 2단계는 측정 후 기록합니다.
   * - 이전 단계
     - :doc:`prerequisites`
   * - 다음 단계
     - :doc:`kubernetes`

선행 조건
=========

* 0단계가 끝나 모든 점검 항목이 O 입니다. (:doc:`prerequisites`)
* 이전 실습에서 만든 VM, 볼륨, 네트워크가 남아 있지 않습니다.

각 단계는 시작 전에 선행 조건을 검사하고, 만족하지 않으면 어느 항목이
문제인지 출력하고 중단합니다.

만들어지는 노드
===============

.. list-table::
   :header-rows: 1

   * - 노드
     - 역할
     - vCPU
     - 메모리
     - 디스크 (qcow2 thin)
     - IP
   * - cp
     - Kubernetes 컨트롤 플레인
     - 4
     - 16GiB
     - 60GB
     - 192.168.100.10
   * - ctrl-worker
     - OpenStack 컨트롤 서비스용 워커
     - 16
     - 32GiB
     - 120GB
     - 192.168.100.11
   * - compute-1
     - 컴퓨트 워커
     - 10
     - 32GiB
     - 80GB
     - 192.168.100.21
   * - compute-2
     - 컴퓨트 워커
     - 10
     - 32GiB
     - 80GB
     - 192.168.100.22

합계는 40 vCPU, 112GiB 메모리, 340GB 디스크입니다. 디스크는 qcow2 thin
provisioning 방식이라 위 값은 최대 크기이고, 실제 사용량만큼만 호스트 디스크를
차지합니다.

.. note::
   사양은 시작점으로 정한 값이며 첫 설치 후 조정될 수 있습니다. 컴퓨트 노드 두
   대는 항상 같은 사양으로 유지합니다. 호스트 메모리가 빠듯하면 컴퓨트를 28GiB
   씩으로 줄입니다.

1단계: 인프라 구성 (Terraform + libvirt)
========================================

개념
----

**Terraform** 은 만들고자 하는 인프라를 코드로 적어 두면 그 상태로 만들어
주는 도구입니다. **libvirt** 는 서버의 KVM 가상화를 관리하는 도구이며,
Terraform 의 libvirt provider 가 둘을 연결합니다. 이 가이드에서는 이 조합으로
노드 VM, 디스크, 네트워크를 만듭니다.

설계
----

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - 항목
     - 내용
   * - 가상 네트워크
     - 이름 ``openinfra-lab``, NAT 방식, ``192.168.100.0/24``, 게이트웨이 ``.1``.
       서버 안에서만 존재하며 외부 접속 경로와는 무관합니다. 검색 도메인(``domain``)은
       설정하지 않습니다.
   * - IP 고정
     - 노드마다 MAC 주소와 IP 를 짝지어 DHCP 예약으로 고정합니다. Kubespray 가 노드
       IP 가 바뀌지 않는다는 전제로 동작하고, 반복 실행 때 결과가 같아야 하기
       때문입니다.
   * - OS 이미지
     - Ubuntu 24.04 (noble) cloud image, 릴리스 ``20261017``. ``current`` 대신
       날짜 폴더로 고정해 재현성을 확보합니다.
   * - 디스크
     - 기준 이미지를 저장소 풀에 한 번 올리고, 노드별 thin qcow2 를 그 이미지를
       기반(backing)으로 만듭니다.
   * - 초기 설정
     - 노드별 cloud-init 디스크(ISO)로 계정 ``kit`` (sudo, SSH 키 전용)과
       호스트명을 설정합니다.
   * - 접속 키
     - 서버 안에서 만든 ``~/.ssh/id_vm_ed25519`` 를 씁니다. 개인키는 서버 밖으로
       내보내지 않습니다.

.. note::
   수동 구축에서는 가상 네트워크에 검색 도메인 ``lab.local`` 을 설정했다가, 5단계에서
   파드의 이름 풀이가 틀어지는 문제를 만나 노드마다 스크립트로 우회했습니다. 키트는
   원인이 된 설정 자체를 만들지 않습니다. 설정을 지워도 가상 네트워크가 정상적으로
   만들어지는지, 파드의 ``search`` 에서 ``lab.local`` 이 사라지는지는 키트 전체
   리허설에서 확인할 예정입니다.

준비: OS 이미지 받기
--------------------

.. code-block:: bash

   mkdir -p ~/images && cd ~/images
   curl -fsSLO https://cloud-images.ubuntu.com/noble/20261017/noble-server-cloudimg-amd64.img
   curl -fsSLO https://cloud-images.ubuntu.com/noble/20261017/SHA256SUMS
   sha256sum -c --ignore-missing SHA256SUMS

``OK`` 가 나와야 합니다. 이 가이드가 사용한 이미지의 SHA256 은 다음과 같습니다.

.. code-block:: text

   04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94  noble-server-cloudimg-amd64.img

.. note::
   호스트 이름(``cloud-images.ubuntu.com``)과 파일 이름은 확인했지만, 날짜 폴더 주소
   (``/noble/20261017/``)로 내려받는 것은 키트 리허설에서 다시 확인할 예정입니다.

노드 접속용 키도 만듭니다.

.. code-block:: bash

   ssh-keygen -t ed25519 -f ~/.ssh/id_vm_ed25519

준비: AppArmor 허용 규칙
------------------------

호스트에서 AppArmor 가 켜져 있으면 VM 을 시작할 때 기준 이미지를 열지 못하고
``Permission denied`` 로 실패할 수 있습니다. 디스크가 있는 폴더를 VM 이 읽고 쓸 수
있게 허용 규칙을 한 줄 추가합니다.

.. code-block:: bash

   RULE='/var/lib/libvirt/images/** rwk,'
   FILE=/etc/apparmor.d/local/abstractions/libvirt-qemu
   grep -qxF "$RULE" "$FILE" 2>/dev/null || echo "$RULE" | sudo tee -a "$FILE"

규칙은 VM 이 시작될 때 libvirt 가 로드하므로 AppArmor 를 따로 다시 읽을 필요가
없습니다. 이 규칙은 AppArmor 를 끄지 않고 켠 채로 문제를 해결합니다.

.. warning::
   이 규칙은 풀 폴더 전체를 허용하는 넓은 범위입니다. 실습 환경 기준이며
   운영 환경에는 더 좁은 규칙을 쓰세요. ``qemu.conf`` 에 ``security_driver = "none"``
   을 넣어 AppArmor 를 끄는 방법도 있지만, VM 격리가 약해지므로 권하지 않습니다.

.. note::
   이 규칙을 넣으면 VM 이 시작된다는 것은 확인했지만, 근본 원인(VM 별 허용 목록에
   디스크 경로가 빠진 이유)은 확정하지 못했습니다.

수행
----

.. code-block:: bash

   make stage-1

내부적으로는 ``terraform/`` 디렉터리에서 다음 순서로 동작합니다.

.. code-block:: bash

   terraform init       # provider 다운로드 (dmacvicar/libvirt 0.9.9)
   terraform validate   # 문법 확인
   terraform plan       # 만들어질 리소스 확인
   terraform apply      # VM, 디스크, 네트워크 생성

코드는 ``versions.tf`` (도구 버전 고정)와 ``main.tf`` (풀, 네트워크, 볼륨,
cloud-init, VM)로 구성됩니다. ``apply`` 가 끝나면 리소스 19개(풀 1, 네트워크 1,
볼륨 9, cloud-init 4, VM 4)가 만들어지며, 이 가이드의 서버에서는 약 1분 30초가
걸렸습니다.

.. note::
   libvirt provider 0.9.x 는 0.8 이하와 문법이 다릅니다. 인터넷의 예제를 그대로
   쓰면 동작하지 않으니, 설치된 provider 의 스키마
   (``terraform providers schema -json``)로 속성 이름을 확인하세요.

확인
----

.. code-block:: bash

   virsh list --all       # 노드 4대가 running 상태
   virsh net-list --all   # openinfra-lab 이 active 상태
   ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 hostname

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - 확인 항목
     - 기대 결과
   * - VM 개수와 이름
     - 노드 4대가 모두 ``running``
   * - 네트워크
     - ``openinfra-lab`` 이 ``active``
   * - IP
     - 위 노드 표의 IP 4개가 정상
   * - SSH 접속
     - 각 노드에 키로 접속됨
   * - 시계
     - 노드 4대 모두 동기화됨

노드 안에서 확인한 실제 사양은 다음과 같습니다. 메모리와 디스크는 할당값에서
운영체제가 쓰는 몫을 뺀 값이라 표의 값보다 조금 작게 보입니다.

.. list-table::
   :header-rows: 1

   * - 노드
     - IP
     - vCPU
     - 메모리(실측)
     - 루트 디스크
   * - cp
     - 192.168.100.10
     - 4
     - 15GiB
     - 58GB
   * - ctrl-worker
     - 192.168.100.11
     - 16
     - 31GiB
     - 116GB
   * - compute-1
     - 192.168.100.21
     - 10
     - 31GiB
     - 77GB
   * - compute-2
     - 192.168.100.22
     - 10
     - 31GiB
     - 77GB

.. warning::
   VM 을 지웠다가 같은 IP 로 다시 만들면 노드의 SSH 지문이 바뀌어 접속이
   ``REMOTE HOST IDENTIFICATION HAS CHANGED`` 로 막힙니다. 이전 지문을 지우면
   됩니다. 처음 접속하는 노드에서 ``Permanently added`` 경고가 나오는 것은
   정상입니다.

   .. code-block:: bash

      ssh-keygen -R 192.168.100.10

2단계: 노드 사전 설정 (Ansible)
===============================

개념
----

**Ansible** 은 여러 서버에 같은 설정을 반복 없이 적용하는 도구입니다.
Kubernetes 는 노드가 특정 조건을 만족해야 설치되므로, Kubespray 를 실행하기
전에 모든 노드를 같은 상태로 맞춥니다. Ansible 은 0단계에서 만든
``~/venv-kubespray`` 안에 있으므로 활성화한 뒤 실행합니다.

인벤토리와 설정
---------------

Ansible 은 **인벤토리** 파일의 노드 목록에 접속합니다. 키트는 1단계에서 Terraform 이
만든 VM 정보(이름, IP)로 이 인벤토리를 **자동으로 생성**\ 합니다. 사람이 IP 를 옮겨
적지 않으므로 VM 구성이 바뀌어도 다음 단계가 그대로 이어집니다. 생성되는 인벤토리는
다음과 같은 모습입니다.

.. code-block:: ini

   # ansible/inventory.ini
   [kube_control_plane]
   cp           ansible_host=192.168.100.10 ip=192.168.100.10 access_ip=192.168.100.10

   [etcd]
   cp           ansible_host=192.168.100.10 ip=192.168.100.10 access_ip=192.168.100.10

   [kube_node]
   ctrl-worker  ansible_host=192.168.100.11 ip=192.168.100.11 access_ip=192.168.100.11
   compute-1    ansible_host=192.168.100.21 ip=192.168.100.21 access_ip=192.168.100.21
   compute-2    ansible_host=192.168.100.22 ip=192.168.100.22 access_ip=192.168.100.22

   [k8s_cluster:children]
   kube_control_plane
   kube_node

그룹 이름은 다음 단계의 Kubespray 가 요구하는 이름입니다. 컴퓨트 노드를 위한
별도 그룹은 없고, 워커 3대가 ``kube_node`` 에 속합니다. ``ip`` 와 ``access_ip``
를 노드마다 적어 두는 이유는 Kubernetes 가 노드의 내부 주소를 올바르게
잡도록 하기 위해서입니다.

.. code-block:: ini

   # ansible/ansible.cfg
   [defaults]
   remote_user = kit
   private_key_file = ~/.ssh/id_vm_ed25519
   host_key_checking = False
   interpreter_python = auto_silent

.. note::
   수동 구축에서는 IP 가 고정되어 있어 이 파일을 직접 작성했습니다. 위 예시는 그때
   쓴 파일의 형태입니다. 생성 방식(Terraform 출력에서 파일로 변환)의 세부와 파일 위치는
   키트 구현 예정입니다.

접속 확인
---------

.. code-block:: bash

   source ~/venv-kubespray/bin/activate
   cd ansible
   ansible all -m ping    # 4대 모두 pong

수행
----

.. code-block:: bash

   make stage-2

내부적으로는 플레이북 ``prepare-nodes.yml`` 을 4대에 적용합니다.

.. list-table::
   :header-rows: 1
   :widths: 25 45 30

   * - 항목
     - 내용
     - 이유
   * - swap
     - swap 을 끄고 재부팅 후에도 꺼진 상태를 유지
     - kubelet 요구 사항 (이 이미지는 이미 꺼져 있음)
   * - 커널 모듈
     - ``overlay``, ``br_netfilter`` 로드
     - 컨테이너와 네트워킹 요구
   * - 커널 파라미터
     - ``net.ipv4.ip_forward`` 등 네트워크 설정
     - Kubernetes 네트워킹 요구
   * - 노드 이름 등록
     - ``/etc/hosts`` 와 cloud-init 템플릿에 노드 주소 등록
     - 노드끼리 이름으로 부르기 위함. 템플릿에 넣어 재부팅 후에도 유지
   * - 기본 패키지
     - 이후 단계에서 쓰는 패키지 설치
     - 이후 단계의 의존성

시간 동기화와 호스트명은 이 플레이북이 설정하지 않습니다. 호스트명은 1단계의
cloud-init 이 정하고, 시간 동기화는 Ubuntu 기본인 ``systemd-timesyncd`` 가 이미
외부 시간 서버(``ntp.ubuntu.com``)에 맞추고 있어 확인만 합니다.

.. note::
   노드는 호스트와 달리 ``chrony`` 가 아니라 ``systemd-timesyncd`` 를 씁니다.
   노드도 외부 시간 서버(UDP 123)를 쓰므로 키트는 이 포트가 허용된 환경에
   의존합니다.

재실행 확인
-----------

플레이북은 다시 실행해도 같은 상태를 유지해야 합니다(멱등성). 두 번째 실행에서
4대 모두 아래처럼 나오면 정상입니다.

.. code-block:: text

   ok=9  changed=0  unreachable=0  failed=0

확인
----

.. code-block:: bash

   ansible all -m shell -a 'swapon --show | wc -l'                              # 0
   ansible all -m shell -a 'lsmod | grep -E "^(overlay|br_netfilter)" | wc -l' # 2
   ansible all -m shell -a 'sysctl -n net.ipv4.ip_forward'                      # 1
   ansible all -m shell -a 'grep -c 192.168.100 /etc/hosts || true'             # 4
   ansible all -m shell -a 'timedatectl | grep synchronized'                    # yes

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - 확인 항목
     - 기대 결과
   * - 노드 접속
     - 4대 모두 ``pong``
   * - swap
     - 모든 노드에서 꺼져 있음 (``swapon --show`` 출력 없음)
   * - 커널 모듈
     - ``overlay``, ``br_netfilter`` 로드됨
   * - ``net.ipv4.ip_forward``
     - ``1``
   * - ``/etc/hosts`` 의 노드 주소
     - 4줄 (적용 전에는 0줄)
   * - 시간 동기화
     - ``yes``

.. note::
   Ansible 의 ``shell`` 모듈에서 ``grep -c`` 는 일치하는 줄이 0개이면 종료 코드 1을
   돌려줘서 ``FAILED`` 로 표시됩니다. 실제 실패가 아니며, 위 명령처럼
   ``|| true`` 로 처리합니다.

알아 둘 점
----------

.. note::
   5단계에서 파드의 이름 풀이가 틀어지는 문제는 가상 네트워크의 검색 도메인 설정에서
   비롯됩니다. 키트는 이 설정을 만들지 않으므로 2단계에서 따로 처리하지 않습니다.
   수동 구축에서 쓴 우회 방법과 증상은 :ref:`troubleshooting` 장에 남깁니다.

두 단계를 한 번에 실행하기
==========================

1~2단계를 따로 실행하지 않고, 전체를 한 번에 실행할 수도 있습니다.

.. code-block:: bash

   make up       # 0단계부터 검증까지 전체 실행

단계별로 학습할 때는 ``make stage-1`` 과 ``make stage-2`` 를 차례로 실행하고,
각 확인 항목을 살펴본 뒤 넘어가길 권합니다.

처음부터 다시 만들기
====================

VM 을 모두 지우고 처음부터 다시 시작하려면 다음 명령을 사용합니다.

.. code-block:: bash

   make destroy

.. warning::
   ``make destroy`` 는 만들어진 VM, 디스크, 네트워크를 삭제합니다.
   노드 안에 남긴 데이터도 함께 사라지므로 필요한 것은 미리 옮겨 두세요.

로그와 소요 시간
================

각 단계의 로그와 소요 시간은 자동으로 기록됩니다(키트 구현 예정). 파일 이름과
형식은 ``common/`` 의 공통 함수에서 통일합니다.

.. code-block:: text

   logs/        # 단계별 로그와 소요 시간

실패하면 어느 단계의 어느 항목에서, 어떤 원인일 수 있는지와 로그 위치가
함께 출력됩니다. 1단계가 VM 시작 단계에서 실패하면 커널 로그와 libvirtd 로그,
VM 별 AppArmor 프로파일을 지정한 폴더에 저장해 원인을 찾는 데 쓰도록
구현할 예정입니다.

확인
====

이 장이 끝났다면 다음 조건을 모두 만족해야 합니다.

* 노드 VM 4대가 ``running`` 상태이고 고정 IP 4개가 정상
* 키로 4대 모두에 접속됨
* Ansible 로 4대 모두에 접속(``pong``)되고 재실행 결과가 ``changed=0``
* 모든 노드에서 swap 이 꺼져 있고, 커널 모듈과 ``ip_forward`` 가 적용되었으며,
  ``/etc/hosts`` 에 노드 주소 4줄이 있음

모두 만족하면 :doc:`kubernetes` 로 넘어갑니다.

자주 만나는 오류
================

이 장의 단계에서 만나는 오류와 해결 방법은 :ref:`troubleshooting` 장에
모아 둡니다. 구축을 진행하며 만난 실패를 "증상 → 원인 → 해결" 형식으로
추가하세요.