0단계. 서버 확인과 
설치 도구를 나누는 이유
------------------------------------------------------------------------------------------

Terraform은 VM과 네트워크를 만들고, Ansible과 Kubespray는 VM 내부 설정과
Kubernetes 설치를 담당합니다. kubectl은 Kubernetes 상태를 확인하고,
Helm은 OpenStack 서비스 배포에 사용합니다.
Python 가상환경은 도구마다 필요한 Python 패키지를 분리하는 폴더입니다.
여기서 말하는 가상환경은 서버 역할의 VM과 다릅니다.
``source .../activate`` 로 사용할 환경을 선택하고 ``deactivate`` 로 해제합니다.

도구 설치
==========================================================================================

이 단계의 목표와 실행 위치
------------------------------------------------------------------------------------------

이 단계에서는 Ubuntu 호스트가 VM을 실행할 수 있는지 확인하고 필요한 도구를 설치합니다.
서버에 SSH로 접속한 ``lab`` 계정에서 진행합니다. 아직 노드 VM에 들어가서 작업하는 단계가 아닙니다.
서버 이름과 계정을 확인하고, 필요한 자료를 받은 뒤 시작합니다.


먼저 호스트에서 VM을 실행할 수 있는지 확인했습니다. 서버에 SSH로 접속한 뒤 아래 명령을 실행합니다.
이 문서의 셸 명령은 별도 표시가 없으면 Ubuntu 서버에서 실행합니다.

.. code-block:: bash

   systemd-detect-virt
   ls -l /dev/kvm
   lscpu
   free -h
   lsblk
   df -h /
   id

실습 서버에서 ``systemd-detect-virt`` 결과는 ``none`` 이었고 CPU의 ``vmx`` 플래그와 ``/dev/kvm`` 을 확인했습니다.
루트 파일시스템에는 약 452 GB가 남아 있었습니다. 별도로 보인 250 GB 장치 ``rbd0`` 는 용도를 확인하지 못해 사용하지 않았습니다.


처음 사용하는 명령 읽기
------------------------------------------------------------------------------------------

``systemd-detect-virt`` 는 현재 운영체제가 가상 환경에서 실행되는지 확인합니다.
기록의 ``none`` 은 감지된 가상화 환경이 없다는 뜻입니다. ``/dev/kvm`` 은 Linux가
하드웨어 가상화 기능을 사용할 때 접근하는 장치입니다.
``lscpu`` 는 CPU 정보, ``free -h`` 는 메모리, ``lsblk`` 는 저장 장치 구성을 표시합니다.
``df -h /`` 는 루트 파일시스템의 여유 공간, ``id`` 는 사용자와 소속 그룹을 보여 줍니다.
이 명령들은 상태 조회용이며 VM을 생성하지 않습니다.

계정과 접속 키 준비
------------------------------------------------------------------------------------------

호스트에서 ``sudo -v`` 로 관리자 권한을 확인하세요. ``lab`` 은 실습용 호스트 계정입니다.
계정이 없다면 서버 관리자에게 SSH 공개키 등록과 sudo 권한을 요청합니다.
아래 키는 다음 단계에서 호스트가 네 VM에 접속할 때 사용합니다.

.. code-block:: bash

   mkdir -p ~/.ssh ~/logs
   chmod 700 ~/.ssh
   test -f ~/.ssh/id_vm_ed25519 || ssh-keygen -t ed25519 -f ~/.ssh/id_vm_ed25519
   ls ~/.ssh/id_vm_ed25519.pub

cloud-init에는 끝이 ``.pub`` 인 공개키만 등록합니다. 키에 암호를 설정했다면 Ansible 실행 전
``ssh-agent`` 에 키를 등록하세요. 계정의 KVM 접근 권한은 ``id`` 와 ``ls -l /dev/kvm`` 으로 확인합니다.


작업 세션 유지하기 (tmux)
------------------------------------------------------------------------------------------

SSH 접속이 끊기면 그 터미널에서 실행 중이던 명령도 함께 종료됩니다.
Terraform, Kubespray, Helm 설치는 수 분에서 수십 분이 걸리므로, 도중에 접속이 끊기면
작업이 중간 상태로 남을 수 있습니다. ``tmux`` 는 서버 안에 터미널 세션을 만들어 두고
그 세션에 접속하는 도구라서, 접속이 끊겨도 세션과 그 안의 작업이 계속 실행됩니다.

.. code-block:: bash

   tmux new -s kit          # 'kit' 이름의 세션 만들기
   # (작업 중 접속이 끊겼다면 다시 SSH 접속한 뒤)
   tmux attach -t kit       # 끊기기 전 화면 그대로 다시 붙기

세션에서 나갈 때는 ``Ctrl+B`` 를 누른 뒤 ``D`` 를 눌러 분리(detach)합니다.
세션 안에서 ``exit`` 나 ``Ctrl+D`` 를 입력하면 세션 자체가 닫히므로, 실행 중인 작업이 있을 때는 피합니다.


``source`` 는 파일의 내용을 지금 사용 중인 셸 안에서 그대로 실행하는 명령입니다.
``bash activate`` 처럼 실행하면 새 셸이 열려 설정이 그 안에서만 적용되고 끝나면 사라지지만,
``source`` 로 실행하면 바뀐 설정이 현재 터미널에 남습니다. ``activate`` 는 현재 셸의
``PATH`` 맨 앞에 ``~/venv-kubespray/bin`` 을 추가해, ``ansible`` 과 ``pip`` 를 입력했을 때
시스템 것이 아니라 가상환경 안의 것이 실행되게 합니다. 프롬프트에 ``(venv-kubespray)`` 가 보이면 활성화된 상태입니다.
이 설정은 터미널(tmux 창)마다 따로 적용해야 하며, ``deactivate`` 로 해제합니다.
Kubespray는 ansible-core 2.18.x를 요구하므로, 시스템 Python과 분리해 버전 충돌을 막기 위해 가상환경을 사용합니다.


시간 동기화와 외부 접속
------------------------------------------------------------------------------------------

시간 동기화에 실패해 Cloudv ELCAP의 아웃바운드 정책에서 NTP(UDP 123)를 허용했습니다.
호스트 시계를 약 366초 보정한 뒤 ``chronyc tracking`` 과 ``chronyc sources -v`` 로 동기화가 유지되는지 확인했습니다.
Git 저장소는 외부 SSH 연결이 제한돼 HTTPS로 받았습니다.


설치 도구를 나누는 이유
------------------------------------------------------------------------------------------

Terraform은 VM과 네트워크를 만들고, Ansible과 Kubespray는 VM 내부 설정과
Kubernetes 설치를 담당합니다. kubectl은 Kubernetes 상태를 확인하고,
Helm은 OpenStack 서비스 배포에 사용합니다.
Python 가상환경은 도구마다 필요한 Python 패키지를 분리하는 폴더입니다.
여기서 말하는 가상환경은 서버 역할의 VM과 다릅니다.
``source .../activate`` 로 사용할 환경을 선택하고 ``deactivate`` 로 해제합니다.

도구 설치
------------------------------------------------------------------------------------------

sudo를 사용할 수 있는 ``lab`` 계정으로 진행했습니다. Kubespray와 OpenStack CLI는 서로 다른 Python 가상환경에 설치했습니다.

.. code-block:: bash

   # 기본 패키지와 libvirt/KVM (VM을 만들 때 쓰는 가상화 도구)
   sudo apt-get update
   sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients \
     virtinst bridge-utils genisoimage git make curl unzip jq \
     python3-venv python3-pip
   sudo usermod -aG libvirt,kvm lab
   # 그룹은 다시 로그인해야 적용됩니다 (tmux를 나가서 접속을 끊었다가 다시 접속)

   # Terraform 1.15.9 (VM을 코드로 만드는 도구)
   cd /tmp
   curl -fsSLO https://releases.hashicorp.com/terraform/1.15.9/terraform_1.15.9_linux_amd64.zip
   unzip terraform_1.15.9_linux_amd64.zip
   sudo install terraform /usr/local/bin/terraform

   # kubectl v1.35.4 (Kubernetes에 명령을 내리는 도구)
   curl -fsSLO https://dl.k8s.io/release/v1.35.4/bin/linux/amd64/kubectl
   sudo install -m 0755 kubectl /usr/local/bin/kubectl

   # Helm v3.18.4 (Kubernetes 앱 설치 도구)
   curl -fsSLO https://get.helm.sh/helm-v3.18.4-linux-amd64.tar.gz
   tar -xzf helm-v3.18.4-linux-amd64.tar.gz
   sudo install linux-amd64/helm /usr/local/bin/helm

   # Kubespray v2.31.0 와 Ansible (가상환경 안에 설치)
   cd ~
   git clone --branch v2.31.0 --depth 1 https://github.com/kubernetes-sigs/kubespray.git
   python3 -m venv ~/venv-kubespray
   source ~/venv-kubespray/bin/activate
   pip install -U pip
   pip install -r ~/kubespray/requirements.txt
   deactivate

   # openstack CLI (가상환경 안에 설치)
   python3 -m venv ~/venv-openstack
   source ~/venv-openstack/bin/activate
   pip install python-openstackclient==10.5.0
   deactivate

위 그룹 설정은 기본 초안에 누락됐던 ``kvm`` 그룹도 함께 추가합니다.
계정명이 다르면 ``lab`` 을 실제 계정으로 바꿉니다.

설치 후 다시 로그인해 ``virsh -c qemu:///system list --all`` 과 아래 명령을 확인합니다. 실습에서는 설치 후 점검 13개 항목을 통과했습니다.

.. code-block:: bash

   terraform version; kubectl version --client; helm version --short
   source ~/venv-kubespray/bin/activate; ansible --version | head -1; deactivate
   source ~/venv-openstack/bin/activate; openstack --version; deactivate
   git -C ~/kubespray describe --tags
   groups                              # libvirt, kvm 이 보여야 함
   virsh list --all                    # sudo 없이 동작해야 함 (VM 목록은 비어 있음)

다음 단계로 넘어가기 전
------------------------------------------------------------------------------------------

버전 출력이 정상이고, 새 로그인 세션에 libvirt와 kvm 그룹이 적용되었는지 확인합니다.
``virsh`` 는 libvirt가 관리하는 VM을 조회하는 도구입니다. 첫 구축이라면 VM 목록이
비어 있을 수 있습니다. 기존 VM이 보이면 어떤 자원인지 확인한 뒤 실습 환경을 선택합니다.