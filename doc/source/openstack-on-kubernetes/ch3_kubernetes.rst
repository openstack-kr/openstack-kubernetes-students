3단계. Kubespray로 Kubernetes 설치하기
==============================================================

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

.. code:: ini

   [all:vars]
   ansible_user=kit
   ansible_ssh_private_key_file=/home/lab/.ssh/id_vm_ed25519

``group_vars/k8s_cluster/k8s-cluster.yml`` 에서 ``kube_version: 1.35.4`` 를 한 번만 지정합니다.
네트워크 플러그인은 Calico, 컨테이너 런타임은 containerd를 사용했습니다.

.. code:: bash

   cd ~/kubespray
   time ansible-playbook \
     -i ~/openinfra-lab-kit/kubespray/inventory/openinfra/inventory.ini \
     --become cluster.yml 2>&1 | tee ~/logs/kubespray-cluster-$(date +%m%d-%H%M).txt

첫 설치에 10분 55초가 걸렸고 위 두 명령은 ``ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10`` 으로
``cp`` 에 접속해서 실행합니다. 확인이 끝나면 ``exit`` 로 호스트에 돌아옵니다.

네 노드 모두 ``failed=0``, ``unreachable=0`` 이었습니다.
호스트에서 ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 명령으로 cp에 접속한 뒤 아래 두 명령을 실행합니다.

.. code-block:: bash

   sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide
   sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -n kube-system

네 노드 모두 ``Ready`` 였으며 Kubernetes 1.35.4와 containerd 2.2.3을 확인했습니다.