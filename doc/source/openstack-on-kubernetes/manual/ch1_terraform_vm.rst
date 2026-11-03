1단계. Terraform으로 VM 네 대 만들기
======================================================

Terraform은 네트워크·디스크·VM 구성을 정의하고, libvirt provider는 이 구성을 호스트에 적용합니다.
실제 VM은 QEMU/KVM에서 실행됩니다. 각 노드의 IP와 자원은 :doc:`overview` 의 표를 따랐습니다.

호스트에서 이미지와 설정 준비하기
----------------------------------------

팀 설정 디렉터리(``~/openinfra-lab-kit/terraform``)에 ``.tf`` 파일과 cloud-init 템플릿을 놓습니다.
다음 예시는 팀이 사용한 날짜의 Ubuntu 이미지와 체크섬을 받습니다.

.. code-block:: bash

   mkdir -p ~/images && cd ~/images
   image=noble-server-cloudimg-amd64.img
   url=https://cloud-images.ubuntu.com/noble/20261017
   curl -fLO "$url/$image" && curl -fLO "$url/SHA256SUMS"
   sha256sum --ignore-missing -c SHA256SUMS
   ls ~/openinfra-lab-kit/terraform/*.tf

받은 이미지 이름 옆에 ``OK`` 가 떠야 합니다. 날짜별 이미지가 내려간 경우 같은 체크섬의 팀 보관본을 받으세요.
Terraform 변수에서 이미지 경로, SSH 공개키 경로, 스토리지 풀 경로를 실제 호스트와 맞춥니다.
libvirt provider는 ``dmacvicar/libvirt`` 버전 ``0.9.9`` 입니다.

설정 확인 후 적용하기
----------------------------------------

#. Ubuntu Noble 클라우드 이미지의 날짜별 릴리스 ``20261017`` 을 받고 ``SHA256SUMS`` 와 대조합니다.
   qcow2 기본 이미지를 바탕으로 노드별 디스크를 만들고, cloud-init에 호스트 이름과 SSH 공개키를 설정합니다.
#. libvirt NAT 네트워크는 ``192.168.100.0/24``, 게이트웨이는 ``192.168.100.1`` 을 사용합니다.
   노드별 주소를 예약하고 일반 DHCP 범위는 ``.100`` 부터 ``.199`` 까지로 분리했습니다.
#. 팀의 Terraform 설정 파일이 있는 디렉터리에서 실행 계획을 확인하고 적용합니다.

.. code:: bash

   cd ~/openinfra-lab-kit/terraform
   terraform init                 # provider 내려받기
   terraform fmt                  # 코드 모양 정리
   terraform validate             # 문법 검사
   terraform plan -out=tfplan1    # 무엇이 만들어질지 미리 보기
   terraform apply tfplan1        # 실제로 만들기

이번 구성의 리소스는 총 19개입니다. 처음에는 디스크 등의 리소스가 생성된 뒤 VM 시작에서
``Permission denied`` 가 발생했습니다. 같은 오류가 나면 :doc:`ch7_troubleshooting` 의 권한 점검을 먼저 확인합니다.

.. code:: bash

   virsh list --all                           # VM 4대 모두 running
   virsh net-dhcp-leases openinfra-lab        # 고정 IP 4개 (.10, .11, .21, .22)
   ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 hostname     # cp 라고 나옴
   for ip in 10 11 21 22; do
     ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.$ip \
       'hostname; timedatectl | grep synchronized'
   done                                       # 4대 모두 호스트명이 맞고 synchronized: yes
   ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 \
     'curl -s -o /dev/null -w "%{http_code}\n" https://github.com'   # 200 (VM의 외부 통신)

네 대가 모두 ``running`` 이고 각 IP에 SSH로 접속됐습니다. VM 내부에서 확인한 OS는 Ubuntu 24.04.5였습니다.