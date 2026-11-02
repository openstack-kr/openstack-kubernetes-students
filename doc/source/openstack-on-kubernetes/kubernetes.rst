.. _kubernetes:

==================================
Kubernetes 구축 (3단계: Kubespray)
==================================

이 장에서는 Kubespray 로 노드 VM 4대에 Kubernetes 클러스터를 설치합니다.
이 장이 끝나면 노드 4대가 모두 ``Ready`` 상태인 Kubernetes 1.35.4 클러스터가
준비됩니다.

.. list-table::
   :widths: 15 85

   * - 목표
     - 노드 4대에 Kubernetes 를 설치하고 모든 노드가 ``Ready`` 인지 확인합니다.
   * - 사용 도구
     - Kubespray v2.31.0 (Ansible 기반)
   * - 실행 명령
     - ``make stage-3``
   * - 소요 시간
     - 약 11분 (``real`` 10분 55초, 이 가이드의 서버 기준)
   * - 이전 단계
     - :doc:`infrastructure`
   * - 다음 단계
     - :doc:`prereq-components`

개념
====

**Kubernetes** 는 컨테이너를 여러 서버에 나누어 실행하고 관리하는 시스템입니다.
**Kubespray** 는 Ansible 로 Kubernetes 를 설치해 주는 도구로, 클러스터 초기화,
노드 조인, 네트워크 플러그인(CNI) 설치를 한 번에 처리합니다.

이 가이드의 노드 역할은 다음과 같습니다.

.. list-table::
   :header-rows: 1
   :widths: 25 35 40

   * - 노드
     - Kubespray 그룹
     - 역할
   * - cp
     - ``kube_control_plane``, ``etcd``
     - 클러스터를 관리하는 컨트롤 플레인
   * - ctrl-worker
     - ``kube_node``
     - 워커 (이후 OpenStack 컨트롤 서비스 실행)
   * - compute-1, compute-2
     - ``kube_node``
     - 워커 (이후 OpenStack 컴퓨트 서비스 실행)

선행 조건
=========

* 2단계가 끝나 노드 4대에 Ansible 로 접속되고 사전 설정이 적용되어 있습니다.
  (:doc:`infrastructure`)
* 0단계에서 Kubespray v2.31.0 을 ``~/kubespray`` 에 받고 ``~/venv-kubespray`` 에
  Ansible 을 설치했습니다. (:doc:`prerequisites`)
* 노드 VM 에서 외부 저장소에 접속할 수 있습니다. 설치 중에 바이너리와 이미지를
  내려받습니다.

사전 준비
=========

설정 견본 복사
--------------

Kubespray 가 제공하는 설정 견본(``sample``)을 복사해 이 클러스터의 설정으로
씁니다. 저장소 안에 두면 설정을 함께 관리할 수 있습니다.

.. code-block:: bash

   cp -r ~/kubespray/inventory/sample \
         ~/openinfra-lab-kit/kubespray/inventory/openinfra

인벤토리 작성
-------------

2단계에서 자동 생성한 노드 목록을 이어서 사용합니다. 노드마다 ``ip`` 와 ``access_ip``
가 있어야 하며, 접속 계정과 키는 ``[all:vars]`` 에 적습니다. 키트는 이 파일도
Terraform 이 만든 VM 정보로 생성합니다.

.. code-block:: ini

   # kubespray/inventory/openinfra/inventory.ini
   (노드 목록: 2단계의 인벤토리와 같음)

   [all:vars]
   ansible_user=kit
   ansible_ssh_private_key_file=~/.ssh/id_vm_ed25519
   ansible_ssh_common_args='-o StrictHostKeyChecking=no'

.. note::
   ``[all:vars]`` 에 쓴 SSH 옵션은 수동 구축에서 사용한 값의 예시입니다. 키트의
   인벤토리 생성 방식에 맞춰 수정하세요.

Kubernetes 버전 고정
--------------------

설치할 버전을 ``group_vars/k8s_cluster/k8s-cluster.yml`` 에 직접 적어 고정합니다.

.. code-block:: yaml

   kube_version: 1.35.4

.. warning::
   두 가지에 주의하세요.

   * **버전을 적어 두지 않으면** Kubespray 는 버전 목록(``checksums.yml``)의 첫 항목을
     자동으로 고르므로, 같은 Kubespray 라도 설치되는 버전이 바뀔 수 있습니다.
     반복 실행에서 같은 결과를 얻으려면 고정해야 합니다.
   * **v 를 붙이지 않습니다.** 목록의 형식이 ``1.35.4`` 이므로 ``v1.35.4`` 로 적으면
     "버전이 목록에 없음" 오류가 설치 시작 때 날 수 있습니다. 이 가이드에서는 이를
     미리 확인해 오류를 피했습니다.

네트워크 플러그인과 컨테이너 런타임
-----------------------------------

견본의 기본값을 그대로 씁니다. 바꿀 이유가 없으면 변경하지 않습니다.

.. list-table::
   :header-rows: 1
   :widths: 30 30 40

   * - 항목
     - 값
     - 비고
   * - 네트워크 플러그인 (CNI)
     - ``calico``
     - Kubespray 기본값
   * - 컨테이너 런타임
     - ``containerd``
     - Kubespray 기본값 (설치 결과 2.2.3)

사전 점검
---------

설치 전에 다음을 확인하면 시작 단계의 오류를 줄일 수 있습니다.

.. code-block:: bash

   source ~/venv-kubespray/bin/activate
   INV=~/openinfra-lab-kit/kubespray/inventory/openinfra

   # 1) 노드 4대 접속
   ansible -i $INV/inventory.ini all -m ping

   # 2) access_ip 가 노드마다 있는지 (4)
   grep -c access_ip $INV/inventory.ini

   # 3) 버전이 한 줄로 고정되어 있는지 (1)
   grep -n '^kube_version' $INV/group_vars/k8s_cluster/k8s-cluster.yml

   # 4) 노드에서 외부 저장소 접속 (000 이 없어야 함)
   ansible -i $INV/inventory.ini all -m shell -a \
     'for h in registry.k8s.io quay.io github.com dl.k8s.io docker.io ghcr.io; do
        echo -n "$h "; curl -s -o /dev/null -m 10 -w "%{http_code}\n" https://$h; done'

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - 점검 항목
     - 기대 결과
   * - ``ansible ... ping``
     - 4대 모두 ``pong``
   * - ``access_ip`` 줄 수
     - 4
   * - ``kube_version`` 줄 수
     - 1
   * - 외부 저장소 접속
     - 응답 코드가 나오고 ``000`` 이 없음 (``000`` 은 연결 실패)

수행
====

.. code-block:: bash

   make stage-3

내부적으로는 Kubespray 의 ``cluster.yml`` 플레이북을 실행합니다.

.. code-block:: bash

   source ~/venv-kubespray/bin/activate
   cd ~/kubespray
   time ansible-playbook \
     -i ~/openinfra-lab-kit/kubespray/inventory/openinfra/inventory.ini \
     --become cluster.yml

실행에는 약 11분이 걸리며, 가장 오래 걸리는 작업은 이미지와 바이너리 다운로드
(최대 약 38초)입니다.

설치 결과 읽기
--------------

실행이 끝나면 마지막에 ``PLAY RECAP`` 이 출력됩니다. 확인할 것은 노드마다
``failed=0`` 과 ``unreachable=0`` 입니다.

.. list-table::
   :header-rows: 1

   * - 노드
     - ok
     - changed
     - failed
     - unreachable
     - 비고
   * - cp
     - 611
     - 132
     - 0
     - 0
     - ignored 4
   * - ctrl-worker
     - 429
     - 85
     - 0
     - 0
     -
   * - compute-1
     - 429
     - 85
     - 0
     - 0
     -
   * - compute-2
     - 429
     - 85
     - 0
     - 0
     -

.. note::
   ``ignored=4`` 는 Kubespray 가 실패해도 계속 진행하도록 정의해 둔 작업이 4개
   있었다는 뜻입니다. ``failed=0`` 이면 문제가 아닙니다. 위 수치는 이 가이드의 서버에서
   얻은 값이며 환경에 따라 달라질 수 있습니다.

확인
====

노드 상태를 확인합니다. 4단계에서 서버에 ``kubectl`` 설정을 만들기 전이므로,
컨트롤 플레인 노드(cp)에서 실행합니다.

.. code-block:: bash

   ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 \
     'sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes -o wide'

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - 확인 항목
     - 기대 결과
   * - 노드 개수와 상태
     - 4대(cp, ctrl-worker, compute-1, compute-2) 모두 ``Ready``
   * - Kubernetes 버전
     - 4대 모두 ``v1.35.4``
   * - 내부 IP
     - ``192.168.100.10``, ``.11``, ``.21``, ``.22`` (루프백 주소가 아님)
   * - OS 와 커널
     - Ubuntu 24.04.5 LTS, ``6.8.0-147-generic``
   * - 컨테이너 런타임
     - ``containerd://2.2.3``
   * - 워커의 ``ROLES``
     - ``<none>`` (정상)

.. note::
   워커 노드의 ``ROLES`` 가 ``<none>`` 인 것은 정상입니다. OpenStack-Helm 이 쓰는
   역할 레이블은 다음 단계(:doc:`prereq-components`)에서 붙입니다.

모든 파드가 정상인지도 확인합니다.

.. code-block:: bash

   ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 \
     'sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get pods -A'

``STATUS`` 가 모두 ``Running`` 이어야 합니다.

.. note::
   노드 VM 의 OS 와 커널(24.04.5, 6.8.0-147)은 호스트(24.04.1, 6.8.0-51)와 다릅니다.
   버전을 기록할 때는 호스트와 노드 VM 을 따로 적으세요.

로그와 소요 시간
================

3단계의 로그와 소요 시간은 ``logs/`` 에 자동으로 기록됩니다(키트 구현 예정). 직접 실행했다면
``time`` 이 출력하는 ``real`` 값이 소요 시간입니다. 실패하면 어느 작업에서
멈췄는지가 ``PLAY RECAP`` 위쪽의 ``fatal`` 메시지에 나옵니다.

확인 요약
=========

이 장이 끝났다면 다음 조건을 모두 만족해야 합니다.

* ``PLAY RECAP`` 에서 4대 모두 ``failed=0``, ``unreachable=0``
* 노드 4대가 모두 ``Ready`` 이고 버전이 ``v1.35.4``
* 모든 파드가 ``Running``

모두 만족하면 :doc:`prereq-components` 로 넘어갑니다.

자주 만나는 오류
================

이 장의 단계에서 만나는 오류와 해결 방법은 :ref:`troubleshooting` 장에
모아 둡니다. 이 장에서 미리 알아 둘 것은 다음 한 가지입니다.

* ``kube_version`` 은 ``v`` 없이(``1.35.4``) 적습니다. 형식이 다르면 설치 시작
  때 "버전이 목록에 없음" 오류가 날 수 있습니다.