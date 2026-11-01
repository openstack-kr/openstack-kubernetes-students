.. _prerequisites:

========================================
사전 준비 (0단계: 환경 점검과 도구 설치)
========================================

구축을 시작하기 전에 서버가 이 가이드의 구조를 올릴 수 있는 상태인지 점검하고,
구축에 필요한 도구를 설치합니다. 이 단계에서 문제를 걸러 두면 뒤 단계에서
원인을 알기 어려운 실패를 만나는 일을 줄일 수 있습니다.

.. list-table::
   :widths: 15 85

   * - 목표
     - 서버가 구축 조건을 만족하는지 확인하고, 필요한 도구를 정해진 버전으로 설치합니다.
   * - 소요 시간
     - 순수 도구 설치 약 30분 (수동 구축 기준, 네트워크 문제 해결 시간 제외)
   * - 실행 명령
     - ``make preflight`` (점검만), ``make install`` (점검 + 설치 + 설치 후 점검)
   * - 다음 단계
     - :doc:`infrastructure`

0단계가 하는 일
===============

0단계는 세 부분으로 이루어집니다.

1. **설치 전 점검**: 서버가 조건을 만족하는지 확인합니다.
2. **도구 설치**: ``versions.env`` 에 적힌 버전대로 도구를 설치합니다.
3. **설치 후 점검**: 도구가 올바른 버전으로 설치되었고 깨끗한 상태인지 확인합니다.

각 점검 항목은 O/X 로 판정합니다. 하나라도 X 이면 항목, 기준값, 실제값,
가능한 원인을 출력하고 중단합니다.

.. note::
   0단계는 처음 한 번만 수행하면 됩니다. 이미 설치된 도구는 건너뛰므로
   ``make up`` 으로 전체를 실행해도 다시 설치하지 않으며, 여러 번 실행해도
   안전합니다. 설치된 버전이 ``versions.env`` 와 다르면 알려 줍니다.

선행 조건
=========

이 가이드는 **베어메탈 서버 한 대**\ 를 전제로 합니다. libvirt/KVM 으로 노드 VM
4대를 직접 만들기 때문입니다. 가상 서버(인스턴스) 안에서는 가상화 기능을
쓸 수 없어 1단계가 진행되지 않을 수 있습니다.

필요한 것은 다음과 같습니다.

* Ubuntu 24.04 (Noble) 가 설치된 서버. 다른 버전은 이 가이드가 검증하지 않았습니다.
* ``sudo`` 권한이 있는 일반 계정 (root 로 직접 작업하지 않습니다)
* 외부 네트워크 접속: 패키지 저장소와 바이너리 다운로드 주소, 컨테이너 이미지
  저장소(80, 443), 그리고 **시간 서버(UDP 123)**
* 저장소 복제에 쓸 ``git``

.. warning::
   서버 업체의 방화벽이 나가는 UDP 123 을 막고 있으면 시간 동기화가 되지 않습니다.
   노드 VM 도 같은 경로로 외부 시간 서버를 쓰므로, 이 환경에서는 UDP 123 을
   허용해야 합니다. 이 가이드의 서버에서 실제로 겪은 사례는
   :ref:`prerequisites-ntp` 를 참고하세요.

서버 요구 사양
--------------

노드 VM 4대의 합계와 호스트가 쓸 여유분을 더한 값이 기준입니다.

.. list-table::
   :header-rows: 1
   :widths: 20 30 50

   * - 자원
     - 노드 VM 합계
     - 서버에 필요한 값
   * - CPU
     - 40 vCPU
     - 40 스레드 이상
   * - 메모리
     - 112GiB
     - 120GiB 이상. 128GB 로 표기된 서버는 ``free`` 에서 약 125GiB 로 보이며,
       VM 배정 후 호스트에 약 13GiB 가 남습니다.
   * - 디스크
     - 340GB (thin provisioning)
     - 340GB 이상의 여유 공간

.. note::
   노드 사양은 시작점으로 정한 값이라 첫 설치 후 조정될 수 있습니다. 호스트
   메모리가 빠듯하면 컴퓨트 노드를 28GiB 씩으로 줄입니다. 사양이 바뀌면 점검
   기준값도 함께 바뀝니다.

저장소 받기
===========

.. code-block:: bash

   git clone <저장소 주소> openinfra-lab-kit
   cd openinfra-lab-kit

설치할 도구의 버전은 모두 ``versions.env`` 한 곳에서 관리합니다. 버전을
바꾸고 싶다면 이 파일만 수정하세요.

1. 설치 전 점검
===============

.. code-block:: bash

   make preflight

점검 항목은 다음과 같습니다.

.. list-table::
   :header-rows: 1
   :widths: 15 35 50

   * - 분류
     - 점검 항목
     - 확인 방법
   * - 호스트 유형
     - 베어메탈인가
     - ``systemd-detect-virt`` (결과가 ``none`` 이어야 함)
   * - 가상화
     - KVM 사용 가능
     - ``/dev/kvm`` 존재, CPU 플래그 ``vmx`` (Intel) 확인
   * - 자원
     - CPU, 메모리, 디스크 여유
     - ``nproc``, ``free -h``, ``df -h``
   * - OS
     - 호스트 OS 버전
     - ``/etc/os-release``
   * - 권한
     - sudo 사용 가능, root 가 아닌 계정
     - ``sudo -n true``, ``id -u``
   * - 시간
     - 시간 동기화
     - ``timedatectl`` 의 ``System clock synchronized: yes``
   * - 네트워크
     - 저장소, 다운로드 경로, 이미지 레지스트리, 시간 서버(UDP 123) 접근
     - 각 주소로의 접속 시도, ``chronyc sources`` 의 ``Reach`` 가 0 이 아님

직접 확인하려면 아래 명령을 사용할 수 있습니다.

.. code-block:: bash

   systemd-detect-virt        # none 이면 베어메탈
   ls -l /dev/kvm             # 파일이 있어야 함
   grep -c vmx /proc/cpuinfo  # 0 보다 커야 함
   nproc                      # 40 이상
   free -h                    # 총 메모리 120GiB 이상
   df -h                      # 여유 공간 340GB 이상
   cat /etc/os-release        # Ubuntu 24.04
   timedatectl | grep synchronized   # yes
   chronyc sources            # Reach 가 0 이 아니어야 함

점검 결과 읽기
--------------

모든 항목이 O 이면 다음 절로 넘어갑니다. 미달 항목이 있으면 다음 형식으로
출력하고 중단합니다.

.. code-block:: text

   [X] 가상화: /dev/kvm
       기준값 : 존재
       실제값 : 없음
       원인   : BIOS 에서 가상화가 꺼져 있거나, 서버가 가상 서버(인스턴스)일 수 있음
       로그   : logs/stage0/preflight.log

.. note::
   위 출력은 형식을 보여 주는 예시(키트 구현 예정)입니다. 실제 메시지 문구는
   구현에 따라 달라질 수 있습니다.

.. warning::
   호스트 유형 점검에서 베어메탈이 아니라고 나오면 점검이 중단됩니다.
   가상 서버에서는 libvirt 로 노드 VM 을 만드는 1단계를 진행하기 어렵습니다.
   이 경우 서버를 확인한 뒤 진행하세요.

.. _prerequisites-ntp:

예: 시간 동기화가 되지 않을 때
------------------------------

이 가이드의 서버에서 실제로 만난 사례입니다.

.. list-table::
   :widths: 15 85

   * - 증상
     - ``chronyc sources`` 에서 ``Reach`` 가 ``0`` 이고 ``Not synchronised`` 로 나옴
   * - 진단
     - 이름 풀이(``getent hosts``)는 성공하므로 DNS 문제가 아닙니다. NTP 를 직접
       시험(Python)해도 시간 초과이므로 chrony 설정 문제도 아닙니다. HTTPS(443)와
       DNS(53)는 동작하므로 **특정 포트만** 막힌 것입니다.
   * - 원인
     - 서버 업체 방화벽의 "나가는 목적지 포트" 목록에 UDP 123 이 없었습니다.
   * - 해결
     - 방화벽 설정에서 ``NTP / UDP / 123`` 을 추가했습니다. 이후 ``Reach`` 가
       ``377`` 이 되고 ``System clock synchronized: yes`` 가 되었습니다.

.. code-block:: bash

   chronyc sources
   chronyc tracking
   timedatectl | grep -E "synchronized|NTP"

서버 시계가 실제보다 크게 어긋나 있으면 (이 서버는 약 366초 빨랐음) 동기화가
된 뒤에 한 번 보정할 수 있습니다.

.. code-block:: bash

   sudo chronyc makestep

.. note::
   시계를 보정하면 그 전후로 로그와 쉘 히스토리의 시각이 겹쳐 보일 수 있습니다.
   기록을 남기는 구축이라면 시계를 먼저 맞추고 시작하세요.

2. 도구 설치
============

.. code-block:: bash

   make install

점검을 통과하면 다음 도구를 ``versions.env`` 의 버전대로 설치합니다.

.. list-table::
   :header-rows: 1
   :widths: 30 30 25 15

   * - 도구
     - 설치 방식
     - 버전
     - 쓰이는 단계
   * - qemu-kvm, libvirt 등 호스트 패키지
     - apt 패키지
     - Ubuntu 저장소 기준
     - 1
   * - Terraform
     - 바이너리
     - 1.15.9
     - 1
   * - Terraform libvirt provider
     - ``terraform init`` 시 자동 다운로드
     - 0.9.9
     - 1
   * - Kubespray
     - ``git clone`` (태그 고정)
     - v2.31.0 (커밋 ``1c9add4``)
     - 3
   * - Ansible
     - Python 가상환경 ``~/venv-kubespray`` (Kubespray 의 ``requirements.txt``)
     - ansible-core 2.18.19
     - 2~3
   * - kubectl
     - 바이너리
     - v1.35.4
     - 4~6
   * - Helm
     - 바이너리
     - v3.18.4
     - 4~6
   * - openstack CLI
     - Python 가상환경 ``~/venv-openstack``
     - 10.5.0
     - 6

.. note::
   Ansible 과 openstack CLI 는 각각 가상환경 안에 설치됩니다. 이 도구들을 직접
   실행할 때는 먼저 해당 가상환경을 활성화하세요
   (예: ``source ~/venv-kubespray/bin/activate``). 키트의 ``make`` 명령은
   이 과정을 대신 처리합니다.

권한 설정
---------

VM 을 관리하려면 계정이 ``libvirt`` 그룹에 속해야 합니다. 스크립트가 그룹에
계정을 추가하지만, 그룹 변경은 **새 로그인 세션부터** 적용됩니다.

그룹 변경이 필요했다면 스크립트가 안내 메시지를 출력합니다. 안내에 따라
다시 로그인하거나 아래 명령으로 현재 세션에 적용한 뒤 이어서 실행하세요.

.. code-block:: bash

   newgrp libvirt

다시 실행해도 안전합니다
------------------------

``make install`` 은 여러 번 실행해도 안전합니다.

* 이미 설치된 도구는 건너뜁니다.
* 설치된 버전이 ``versions.env`` 와 다르면 알려 줍니다.
* 설치에 실패하면 어느 도구의 어느 단계에서 실패했는지 출력하고 중단합니다.
  원인을 해결한 뒤 같은 명령을 다시 실행하면 됩니다.

도구를 직접 설치하려면
----------------------

``make install`` 이 하는 일은 아래 명령과 같습니다. 단계별로 이해하고 싶을 때
따라 해 보세요.

**호스트 패키지와 권한**

.. code-block:: bash

   sudo apt-get update
   sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients \
     virtinst bridge-utils genisoimage git make curl unzip jq \
     python3-venv python3-pip
   sudo usermod -aG libvirt "$USER"

**Terraform**

.. code-block:: bash

   cd /tmp
   curl -fsSLO https://releases.hashicorp.com/terraform/1.15.9/terraform_1.15.9_linux_amd64.zip
   unzip terraform_1.15.9_linux_amd64.zip
   sudo install terraform /usr/local/bin/terraform

**kubectl**

.. code-block:: bash

   curl -fsSLO https://dl.k8s.io/release/v1.35.4/bin/linux/amd64/kubectl
   sudo install -m 0755 kubectl /usr/local/bin/kubectl

**Helm**

.. code-block:: bash

   curl -fsSLO https://get.helm.sh/helm-v3.18.4-linux-amd64.tar.gz
   tar -xzf helm-v3.18.4-linux-amd64.tar.gz
   sudo install linux-amd64/helm /usr/local/bin/helm

**Kubespray 와 Ansible** (Ansible 은 Kubespray 가 요구하는 버전으로 설치합니다)

.. code-block:: bash

   cd ~
   git clone --branch v2.31.0 --depth 1 https://github.com/kubernetes-sigs/kubespray.git
   python3 -m venv ~/venv-kubespray
   source ~/venv-kubespray/bin/activate
   pip install -U pip
   pip install -r ~/kubespray/requirements.txt
   deactivate

**openstack CLI**

.. code-block:: bash

   python3 -m venv ~/venv-openstack
   source ~/venv-openstack/bin/activate
   pip install python-openstackclient==10.5.0
   openstack --version
   deactivate

3. 설치 후 점검
===============

설치가 끝나면 자동으로 다음을 점검합니다.

.. list-table::
   :header-rows: 1
   :widths: 15 40 45

   * - 분류
     - 점검 항목
     - 확인 방법
   * - 도구
     - 각 도구가 존재하고 ``versions.env`` 버전과 일치
     - 각 도구의 버전 출력 명령
   * - 도구
     - Kubespray 가 지정한 버전(v2.31.0)의 커밋
     - ``git -C ~/kubespray rev-parse --short=7 HEAD`` 가 ``1c9add4``
   * - 권한
     - root 가 아닌 계정, ``libvirt``, ``kvm`` 그룹 소속
     - ``id -u``, ``id -nG``
   * - 가상화
     - ``/dev/kvm`` 존재, ``sudo`` 없이 ``virsh`` 동작
     - ``virsh list --all``
   * - 초기 상태
     - 잔여 VM, 볼륨, 네트워크가 없음
     - ``virsh list --all``, ``virsh vol-list``, ``virsh net-list --all``
   * - 시간
     - 시간 동기화
     - ``timedatectl`` 의 ``synchronized: yes``

도구 버전은 직접 확인할 수도 있습니다. Ansible 과 openstack CLI 는 가상환경 안에
있으므로 경로를 지정합니다.

.. code-block:: bash

   terraform version
   kubectl version --client
   helm version --short
   ~/venv-kubespray/bin/ansible --version
   ~/venv-openstack/bin/openstack --version

모두 통과했을 때의 점검 결과는 다음과 같은 모습입니다.

.. code-block:: text

   O  terraform v1.15.9
   O  kubectl v1.35.4
   O  helm v3.18.4
   O  ansible-core 2.18.x
   O  openstack CLI
   O  kubespray v2.31.0 커밋
   O  lab 계정이 root 아님
   O  libvirt 그룹
   O  kvm 그룹
   O  /dev/kvm 존재
   O  virsh 동작(sudo 없이)
   O  잔여 VM 없음
   O  시간 동기화

.. note::
   위 출력은 수동 구축 때 쓴 점검 명령의 결과이며, 키트의 출력 형식은 구현 예정입니다.
   항목 이름과 문구는 구현에 따라 달라질 수 있습니다.

``잔여 VM 없음`` 같은 초기 상태 점검은 깨끗한 상태에서 구축을 시작하는지
확인하는 항목입니다. 이전에 만든 VM 이나 네트워크가 남아 있으면 X 로 판정합니다.
이전 실습의 잔여물은 ``make destroy`` 로 정리한 뒤 다시 점검하세요.

확인
====

0단계가 끝났다면 다음 조건을 모두 만족해야 합니다.

* 설치 전 점검의 모든 항목이 O
* 설치된 도구의 버전이 ``versions.env`` 와 일치
* 계정이 ``libvirt``, ``kvm`` 그룹에 속하고 ``sudo`` 없이 ``virsh`` 가 동작
* 시간 동기화가 ``yes``
* 잔여 VM, 볼륨, 네트워크가 없음

모두 만족하면 :doc:`infrastructure` 로 넘어갑니다.

단계별로 실행하는 경우
======================

한 번에 전체를 실행하고 싶다면 ``make up`` 이 0단계부터 검증까지 모두
수행합니다. 이 가이드처럼 단계별로 학습하려면 다음 순서로 실행합니다.

.. code-block:: bash

   make preflight   # 점검만
   make install     # 점검 + 설치 + 설치 후 점검
   make stage-1     # 다음 단계

자주 만나는 오류
================

이 장의 단계에서 만나는 오류와 해결 방법은 :ref:`troubleshooting` 장에
모아 둡니다. 구축을 진행하며 만난 실패를 "증상 → 원인 → 해결" 형식으로
추가하세요.