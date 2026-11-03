0단계. 서버 확인과 도구 설치
==================================

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

계정과 접속 키 준비
----------------------------

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

시간 동기화와 외부 접속
----------------------------

시간 동기화에 실패해 Cloudv ELCAP의 아웃바운드 정책에서 NTP(UDP 123)를 허용했습니다.
호스트 시계를 약 366초 보정한 뒤 ``chronyc tracking`` 과 ``chronyc sources -v`` 로 동기화가 유지되는지 확인했습니다.
Git 저장소는 외부 SSH 연결이 제한돼 HTTPS로 받았습니다.

도구 설치
----------------------------

sudo를 사용할 수 있는 ``lab`` 계정으로 진행했습니다. Kubespray와 OpenStack CLI는 서로 다른 Python 가상환경에 설치했습니다.

.. code:: bash

   # 기본 패키지와 libvirt/KVM (VM을 만들 때 쓰는 가상화 도구)
   sudo apt-get update
   sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients \
     virtinst bridge-utils genisoimage git make curl unzip jq \
     python3-venv python3-pip
   sudo usermod -aG libvirt lab
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

설치 후 다시 로그인해 ``virsh -c qemu:///system list --all`` 과 아래 명령을 확인합니다. 실습에서는 설치 후 점검 13개 항목을 통과했습니다.

.. code:: bash

   terraform version; kubectl version --client; helm version --short
   source ~/venv-kubespray/bin/activate; ansible --version | head -1; deactivate
   source ~/venv-openstack/bin/activate; openstack --version; deactivate
   git -C ~/kubespray describe --tags
   groups                              # libvirt, kvm 이 보여야 함
   virsh list --all                    # sudo 없이 동작해야 함 (VM 목록은 비어 있음)