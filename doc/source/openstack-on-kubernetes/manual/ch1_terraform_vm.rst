1단계. Terraform으로 VM 네 대 만들기
==========================================================================================

이 단계의 목표와 실행 위치
------------------------------------------------------------------------------------------

Ubuntu 호스트에서 Kubernetes 노드가 될 VM 네 대를 만듭니다.
Terraform 설정 파일에는 VM 수, CPU, 메모리, 디스크, IP와 초기 계정 정보가 들어 있습니다.
문서의 명령만으로 이 설정 파일이 만들어지지는 않으므로 팀의 파일을 먼저 준비합니다.


Terraform은 네트워크·디스크·VM 구성을 정의하고, libvirt provider는 이 구성을 호스트에 적용합니다.
실제 VM은 QEMU/KVM에서 실행됩니다. 각 노드의 IP와 자원은 :doc:`overview` 의 표를 따랐습니다.


이미지와 네트워크의 의미
------------------------------------------------------------------------------------------

클라우드 이미지는 VM의 운영체제를 시작할 때 사용하는 디스크 파일입니다.
cloud-init은 첫 부팅 때 계정과 SSH 공개키 등을 설정합니다.
체크섬은 파일 내용으로 계산한 식별값이며, 다운로드한 파일이 준비된 기준 파일과
같은지 비교하는 데 사용합니다. ``OK`` 는 파일 비교가 통과했다는 뜻이며 VM 부팅 성공과는 다릅니다.

NAT 네트워크는 VM이 호스트를 거쳐 외부로 통신하는 구성입니다.
표의 사설 IP는 네 VM을 구분하는 주소이며, Windows에서 접속하는 공인 서버 주소와 다릅니다.

호스트에서 이미지와 설정 준비하기
------------------------------------------------------------------------------------------

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
------------------------------------------------------------------------------------------

#. Ubuntu Noble 클라우드 이미지의 날짜별 릴리스 ``20261017`` 을 받고 ``SHA256SUMS`` 와 대조합니다.
   qcow2 기본 이미지를 바탕으로 노드별 디스크를 만들고, cloud-init에 호스트 이름과 SSH 공개키를 설정합니다.
#. libvirt NAT 네트워크는 ``192.168.100.0/24``, 게이트웨이는 ``192.168.100.1`` 을 사용합니다.
   노드별 주소를 예약하고 일반 DHCP 범위는 ``.100`` 부터 ``.199`` 까지로 분리했습니다.
#. 팀의 Terraform 설정 파일이 있는 디렉터리에서 실행 계획을 확인하고 적용합니다.

.. code-block:: bash

   cd ~/openinfra-lab-kit/terraform
   terraform init                 # provider 내려받기
   terraform fmt                  # 코드 모양 정리
   terraform validate             # 문법 검사
   terraform plan -out=tfplan1    # 무엇이 만들어질지 미리 보기
   terraform apply tfplan1        # 실제로 만들기

이번 구성의 리소스는 총 19개입니다. 처음에는 디스크 등의 리소스가 생성된 뒤 VM 시작에서
``Permission denied`` 가 발생했습니다. 같은 오류가 나면 :doc:`ch8_troubleshooting` 의 권한 점검을 먼저 확인합니다.

.. code-block:: bash

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

결과를 읽는 방법
------------------------------------------------------------------------------------------

``terraform plan`` 은 생성·변경할 자원을 미리 보여 주고, ``apply`` 는 실제로 적용합니다.
예상과 다른 삭제나 변경이 계획에 나오면 그대로 진행하지 않습니다.
``running`` 은 VM 전원이 켜져 있다는 뜻입니다. SSH 접속과 호스트 이름 확인까지
성공해야 다음 단계에서 Ansible이 해당 노드를 사용할 수 있습니다.
기록의 HTTP 200은 당시 외부 요청 결과이며 모든 외부 서비스 접근을 보장하지 않습니다.