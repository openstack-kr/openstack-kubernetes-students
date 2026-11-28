2단계. 노드 이미지 생성 및 Terraform 공용 자원 구성
======================================================================

이 단계에서는 Kubernetes 노드에 사용할 가상 머신 이미지를
생성하고, Terraform으로 OpenStack 공용 인프라를 구성합니다.

이후 CAPO는 여기에서 생성한 이미지, 네트워크, flavor 및
키페어를 사용하여 Kubernetes 노드 가상 머신을 생성합니다.

사전 조건
---------

* 1단계 OpenStack 구축 완료
* OpenStack CLI 사용 가능
* KVM 장치 접근 가능
* 이미지 빌드에 필요한 디스크 여유 공간 확보
* Terraform 1.15.9 설치

.. note::

   Terraform 설치 과정 자체는 이번 실습 기록에 포함되어
   있지 않습니다. 실행 전 설치 및 버전을 확인합니다.

   https://developer.hashicorp.com/terraform/install

KVM 접근 권한 확인
------------------

이미지를 생성하는 사용자가 KVM 장치에 접근할 수
있는지 확인합니다.

.. code-block:: bash

   ls -l /dev/kvm
   test -r /dev/kvm && test -w /dev/kvm && echo "KVM OK"

접근 권한이 없는 경우에만 다음 명령어를 실행합니다.

.. code-block:: bash

   sudo setfacl -m "u:$USER:rw" /dev/kvm

.. note::

   위 ACL 설정은 서버 재부팅 시 사라질 수 있습니다.
   이번 실습에서는 재부팅 후 영구 적용 방법을 검증하지 않았습니다.

이미지 빌드 환경 준비
---------------------

image-builder는 Kubernetes 노드에서 사용할 가상 머신
이미지를 생성하는 도구입니다.

Kolla-Ansible의 Python 패키지와 충돌하지 않도록 별도의
Python 가상환경을 생성합니다.

.. code-block:: bash

   python3 -m venv ~/ib-venv
   source ~/ib-venv/bin/activate

image-builder 저장소를 내려받습니다.

.. code-block:: bash

   cd ~
   git clone https://github.com/kubernetes-sigs/image-builder.git
   cd ~/image-builder
   git checkout 704689a7e24c
   cd images/capi

실습에서 사용한 image-builder 커밋으로 고정하여
빌드 환경의 재현성을 높입니다.

의존성을 설치합니다.

.. code-block:: bash

   time make deps-qemu 2>&1 | tee ~/deps-qemu.log

Kubernetes 버전 설정
--------------------

이미지 빌드에 필요한 설정 파일을 생성합니다.

.. code-block:: bash

   mkdir -p ~/ib-vars
   nano ~/ib-vars/k8s136.json

다음 내용을 작성합니다.

.. code-block:: json

   {
       "kubernetes_series": "v1.36",
       "kubernetes_semver": "v1.36.6",
       "kubernetes_deb_version": "1.36.6-1.1",
       "cpus": "4",
       "memory": "4096"
   }

cpus와 memory는 이미지 빌드에 사용하는 자원 설정입니다.
실제 Kubernetes 노드의 사양은 이후 OpenStack flavor에서
정의합니다.

노드 이미지 빌드
----------------

.. code-block:: bash

   cd ~/image-builder/images/capi

   time make build-qemu-ubuntu-2404 \
       PACKER_VAR_FILES=$HOME/ib-vars/k8s136.json \
       2>&1 | tee ~/image-build.log

이미지 빌드에는 시간이 오래 걸릴 수 있으므로
tmux 환경에서 실행하는 것을 권장합니다.

이번 실습에서는 약 31분이 소요되었습니다.

생성된 이미지 경로를 확인합니다.

.. code-block:: bash

   ls -lh ~/image-builder/images/capi/output/ubuntu-2404-kube-v1.36.6/

다음 명령어로 이미지 형식을 확인합니다.

.. code-block:: bash

   IMAGE_DIR=~/image-builder/images/capi/output
   IMAGE_NAME=ubuntu-2404-kube-v1.36.6

   qemu-img info "$IMAGE_DIR/$IMAGE_NAME/$IMAGE_NAME"

실습에서는 qcow2 형식의 이미지가 생성되었으며,
가상 디스크 크기는 20 GiB였습니다.

SSH 키페어 생성
---------------

OpenStack 가상 머신에 SSH로 접속할 때 사용할
공개 키와 개인 키를 생성합니다.

.. code-block:: bash

   mkdir -p ~/.ssh
   chmod 700 ~/.ssh

   [ -e ~/.ssh/k8s-node-key ] || \
       ssh-keygen -t ed25519 -N '' \
       -C k8s-node -f ~/.ssh/k8s-node-key

.. warning::

   k8s-node-key는 개인 키입니다.
   OpenStack에는 공개 키인 k8s-node-key.pub만 등록합니다.

   비밀번호 없는 개인 키는 전용 실습 환경에서만 사용합니다.

Terraform 공용 자원 구성
------------------------

Terraform은 원하는 인프라 상태를 설정 파일로 정의하고
OpenStack API를 통해 실제 자원을 생성합니다.

이번 단계에서는 다음 자원을 구성합니다.

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - 자원
     - 설정
   * - 외부 네트워크
     - ext-net, flat, physnet1
   * - 외부 서브넷
     - 10.20.20.0/24
   * - 외부망 게이트웨이
     - 10.20.20.1
   * - Floating IP 할당 범위
     - 10.20.20.100 ~ 10.20.20.200
   * - 내부 네트워크
     - k8s-net
   * - 내부 서브넷
     - 10.0.0.0/24
   * - 라우터
     - k8s-router
   * - Flavor
     - k8s-node, 4 vCPU, 8 GiB RAM, 60 GB
   * - 키페어
     - k8s-key
   * - 이미지
     - ubuntu-2404-kube-v1.36.6

Terraform 작업 디렉터리를 생성합니다.

.. code-block:: bash

   mkdir -p ~/tf-common
   cd ~/tf-common
   nano main.tf

main.tf 작성
~~~~~~~~~~~~

다음 내용을 main.tf 파일에 작성합니다.

.. code-block:: hcl

   terraform {
     required_providers {
       openstack = {
         source  = "terraform-provider-openstack/openstack"
         version = "3.4.0"
       }
     }
   }

   provider "openstack" {}

   resource "openstack_networking_network_v2" "ext" {
     name     = "ext-net"
     external = true

     segments {
       network_type     = "flat"
       physical_network = "physnet1"
     }
   }

   resource "openstack_networking_subnet_v2" "ext" {
     name        = "ext-subnet"
     network_id  = openstack_networking_network_v2.ext.id
     cidr        = "10.20.20.0/24"
     ip_version  = 4
     gateway_ip  = "10.20.20.1"
     enable_dhcp = false

     allocation_pool {
       start = "10.20.20.100"
       end   = "10.20.20.200"
     }
   }

   resource "openstack_networking_network_v2" "k8s" {
     name = "k8s-net"
   }

   resource "openstack_networking_subnet_v2" "k8s" {
     name            = "k8s-subnet"
     network_id      = openstack_networking_network_v2.k8s.id
     cidr            = "10.0.0.0/24"
     ip_version      = 4
     dns_nameservers = ["8.8.8.8"]
   }

   resource "openstack_networking_router_v2" "k8s" {
     name                = "k8s-router"
     external_network_id = openstack_networking_network_v2.ext.id
   }

   resource "openstack_networking_router_interface_v2" "k8s" {
     router_id = openstack_networking_router_v2.k8s.id
     subnet_id = openstack_networking_subnet_v2.k8s.id
   }

   resource "openstack_compute_flavor_v2" "node" {
     name      = "k8s-node"
     vcpus     = 4
     ram       = 8192
     disk      = 60
     is_public = true
   }

   resource "openstack_compute_keypair_v2" "node" {
     name       = "k8s-key"
     public_key = file(pathexpand("~/.ssh/k8s-node-key.pub"))
   }

   locals {
     image_name = "ubuntu-2404-kube-v1.36.6"
     image_dir  = "~/image-builder/images/capi/output"
     image_path = "${local.image_dir}/${local.image_name}/${local.image_name}"
   }

   resource "openstack_images_image_v2" "node" {
     name             = local.image_name
     local_file_path  = pathexpand(local.image_path)
     container_format = "bare"
     disk_format      = "qcow2"
     visibility       = "public"
   }

이 설정은 네트워크 2개, 서브넷 2개, 라우터 1개,
라우터 인터페이스 1개, flavor 1개, 키페어 1개,
이미지 1개로 총 9개의 Terraform 관리 자원을 정의합니다.

Terraform 실행
~~~~~~~~~~~~~~

OpenStack 인증 정보를 불러옵니다.

.. code-block:: bash

   source ~/kolla-venv/bin/activate
   source /etc/kolla/admin-openrc.sh
   cd ~/tf-common

   terraform version
   terraform init
   terraform fmt
   terraform validate
   terraform plan

terraform plan은 실제 자원을 생성하지 않고
생성하거나 변경할 자원을 미리 보여줍니다.

계획에 예상하지 않은 자원 변경이나 삭제가 없는지 확인한
뒤 실행합니다.

.. code-block:: bash

   terraform apply

승인 질문이 나타나면 내용을 확인한 후 yes를 입력합니다.

.. warning::

   terraform apply의 출력을 tail 명령어로 제한하면
   승인 질문이 화면에 표시되지 않을 수 있습니다.

Terraform 상태 파일 보호
~~~~~~~~~~~~~~~~~~~~~~~~

Terraform 상태 파일에는 인프라 정보와 민감 정보가
저장될 수 있으므로 공개 저장소에 올리지 않습니다.

새 작업 디렉터리의 .gitignore 파일에 다음 내용을 추가합니다.

.. code-block:: text

   *.tfstate*
   .terraform/
   *.tfplan

Terraform 상태 파일은 이후 자원 변경과 삭제에 필요하므로
안전한 위치에 보관합니다.

공용 자원 확인
--------------

.. code-block:: bash

   openstack image list -c Name -c Status
   openstack network list -c Name
   openstack subnet list -c Name -c Subnet
   openstack router list -c Name -c Status
   openstack flavor list -c Name -c VCPUs -c RAM -c Disk
   openstack keypair list

   terraform state list
   terraform plan

정상적으로 생성된 경우 terraform plan에서
No changes 메시지를 확인할 수 있습니다.

테스트 가상 머신 생성
---------------------

생성한 이미지가 정상적으로 부팅되는지 확인합니다.

.. code-block:: bash

   openstack server create \
       --image ubuntu-2404-kube-v1.36.6 \
       --flavor k8s-node \
       --network k8s-net \
       --key-name k8s-key \
       --wait test-kvm-vm

가상 머신 상태와 콘솔 로그를 확인합니다.

.. code-block:: bash

   openstack server show test-kvm-vm -c status
   openstack console log show test-kvm-vm | tail -5

KVM 사용 여부를 확인합니다.

.. code-block:: bash

   INSTANCE=$(openstack server show test-kvm-vm \
       -c OS-EXT-SRV-ATTR:instance_name -f value)

   sudo docker exec nova_libvirt virsh dumpxml "$INSTANCE" \
       | grep -m1 '<domain type'

출력에 domain type이 kvm으로 표시되는지 확인합니다.

외부 통신 확인
--------------

테스트 가상 머신에 임시 Floating IP와 SSH 접속용
보안 그룹을 구성하여 접속합니다.

노드에서 다음 항목을 확인합니다.

.. code-block:: bash

   getent hosts registry.k8s.io

   curl -s -o /dev/null -w '%{http_code}\n' \
       https://registry.k8s.io/v2/

   curl -s -o /dev/null -w '%{http_code}\n' \
       http://10.10.10.254:5000/v3

레지스트리의 HTTP 401 응답은 인증이 필요하다는 의미이며,
네트워크 연결 자체가 이루어졌음을 보여줍니다.

OpenStack Keystone API에서는 HTTP 200 응답을 확인했습니다.

테스트 자원 정리
----------------

.. warning::

   테스트에 사용한 자원만 삭제합니다.
   Terraform이 생성한 공용 네트워크 및 이미지는 유지합니다.

.. code-block:: bash

   openstack server delete --wait test-kvm-vm

외부 통신 확인을 위해 별도로 생성한 Floating IP와
보안 그룹도 사용이 끝난 뒤 삭제합니다.

.. code-block:: bash

   openstack server list
   openstack floating ip list
   openstack security group list
   terraform plan

완료 기준
---------

* 노드 이미지 빌드 성공
* Goss 검사 실패 0개
* Terraform 관리 자원 9개 생성
* 이미지 상태 active
* 라우터 상태 ACTIVE
* 테스트 가상 머신 상태 ACTIVE
* KVM 가상화 방식 확인
* 외부 레지스트리 및 OpenStack API 접근 가능
* 테스트용 임시 자원 정리
* terraform plan 결과 No changes

참고 문서
---------

* `image-builder OpenStack 이미지 가이드
  <https://image-builder.sigs.k8s.io/capi/providers/openstack>`_
* `Terraform OpenStack Provider
  <https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs>`_
