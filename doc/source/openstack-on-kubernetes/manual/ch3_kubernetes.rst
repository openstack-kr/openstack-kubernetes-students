3단계. Kubespray로 Kubernetes 설치하기
==========================================================================================

이 단계의 목표와 실행 위치
------------------------------------------------------------------------------------------

네 VM을 하나의 Kubernetes 클러스터로 구성합니다.
설치 명령은 Ubuntu 호스트에서 실행하고, 마지막 상태 확인만 cp 노드에 접속하여 수행합니다.
Kubespray는 설치 작업이 작성된 Ansible 프로젝트이므로 Python 가상환경과
앞 단계의 인벤토리를 사용합니다.


Kubespray는 Ansible로 Kubernetes를 설치합니다. 컨트롤 플레인과 etcd는 ``cp`` 한 대에,
워커 역할은 나머지 세 대에 배치했습니다. Kubespray v2.31.0의 샘플 인벤토리를 복사하고 2단계에서 확인한 노드 목록을 사용했습니다.

.. code-block:: bash

   source ~/venv-kubespray/bin/activate
   INV=~/openinfra-lab-kit/kubespray/inventory/openinfra
   mkdir -p ~/openinfra-lab-kit/kubespray/inventory ~/logs
   # 인벤토리를 처음 만들 때 실행
   cp -a ~/kubespray/inventory/sample "$INV"
   cp ~/openinfra-lab-kit/ansible/inventory.ini "$INV/inventory.ini"

인벤토리의 ``[all:vars]`` 에 접속 정보를 넣습니다.

.. code-block:: ini

   [all:vars]
   ansible_user=kit
   ansible_ssh_private_key_file=/home/lab/.ssh/id_vm_ed25519

``group_vars/k8s_cluster/k8s-cluster.yml`` 에서 ``kube_version: 1.35.4`` 를 한 번만 지정합니다.
네트워크 플러그인은 Calico, 컨테이너 런타임은 containerd를 사용했습니다.

.. code-block:: bash

   cd ~/kubespray
   time ansible-playbook \
     -i ~/openinfra-lab-kit/kubespray/inventory/openinfra/inventory.ini \
     --become cluster.yml 2>&1 | tee ~/logs/kubespray-cluster-$(date +%m%d-%H%M).txt

기록상 첫 설치는 10분 55초가 걸렸고 네 노드 모두 ``failed=0``, ``unreachable=0`` 이었습니다.
소요 시간은 서버와 네트워크 상태에 따라 달라집니다.
``tee`` 는 설치 출력을 화면에 보여 주면서 파일에도 저장합니다.
설치 로그의 마지막 ``PLAY RECAP`` 에서 실패와 접속 오류를 확인합니다.

이제 설치 결과를 조회하기 위해 cp 노드에 접속합니다.

.. code-block:: bash

   ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10

다음 두 명령은 **cp 노드 안에서** 실행합니다.

.. code-block:: bash

   sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide
   sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -n kube-system

네 노드 모두 ``Ready`` 였으며 Kubernetes 1.35.4와 containerd 2.2.3을 확인했습니다.

확인을 마친 뒤
------------------------------------------------------------------------------------------

``Ready`` 는 Kubernetes가 해당 노드를 사용할 준비가 되었다는 표시입니다.
Pod는 Kubernetes가 컨테이너를 실행하고 배치하는 기본 단위입니다.
시스템 Pod 상태를 확인하되 실행 상태뿐 아니라 READY 열도 함께 확인합니다.
확인이 끝나면 아래 명령으로 Ubuntu 호스트로 돌아갑니다.

.. code-block:: bash

   exit

다음 단계는 호스트에서 실행합니다. ``hostname`` 으로 현재 위치를 확인합니다.