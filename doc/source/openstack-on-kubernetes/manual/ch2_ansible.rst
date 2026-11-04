2단계. Ansible로 노드 설정 맞추기
==========================================================================================

이 단계의 목표와 실행 위치
------------------------------------------------------------------------------------------

Ubuntu 호스트에서 네 VM에 필요한 설정을 한 번에 적용합니다.
Ansible은 호스트에서 SSH로 각 VM에 접속하여 작업합니다.
인벤토리는 접속 대상 목록이고, 플레이북은 그 대상에 수행할 작업을 적은 YAML 파일입니다.
``inventory.ini`` 와 ``prepare-nodes.yml`` 은 서로 다른 역할을 하므로 둘 다 준비해야 합니다.


노드마다 같은 설정을 반복해서 입력하는 대신 Ansible 플레이북을 실행했습니다.
인벤토리에 네 대의 IP와 역할을 적고, SSH 계정을 ``kit`` 으로 지정했습니다.
일부 노드에서 자기 호스트 이름이 ``127.0.1.1`` 로 해석돼 노드 간 통신에는 ``ip`` 와 ``access_ip`` 를 명시했습니다.

.. code-block:: ini

   [kube_control_plane]
   cp          ansible_host=192.168.100.10 ip=192.168.100.10 access_ip=192.168.100.10

   [etcd]
   cp

   [kube_node]
   ctrl-worker ansible_host=192.168.100.11 ip=192.168.100.11 access_ip=192.168.100.11
   compute-1   ansible_host=192.168.100.21 ip=192.168.100.21 access_ip=192.168.100.21
   compute-2   ansible_host=192.168.100.22 ip=192.168.100.22 access_ip=192.168.100.22

   [k8s_cluster:children]
   kube_control_plane
   kube_node


인벤토리의 항목 읽기
------------------------------------------------------------------------------------------

``ansible_host`` 는 SSH 접속 주소입니다. ``ip`` 와 ``access_ip`` 는 Kubespray가
노드 통신에 사용할 주소를 지정하는 설정입니다. 이 실습에서는 같은 사설 IP를 사용합니다.
대괄호로 묶인 이름은 노드 그룹입니다. ``cp`` 는 관리 노드와 etcd 그룹에 속하고,
나머지 세 대는 워커 그룹에 속합니다.

위 목록을 호스트의 ``~/openinfra-lab-kit/ansible/inventory.ini`` 로 저장합니다.
같은 디렉터리에 팀의 ``prepare-nodes.yml`` 을 놓습니다. 처음 구성한다면 ``ansible.cfg`` 에 다음 접속 정보를 입력합니다.

.. code-block:: ini

   [defaults]
   inventory = inventory.ini
   remote_user = kit
   private_key_file = ~/.ssh/id_vm_ed25519

먼저 SSH로 네 노드에 한 번씩 연결해 호스트 키를 확인하세요. ``ansible all -m ping`` 은
SSH와 원격 Python 실행을 함께 확인합니다. ``UNREACHABLE`` 이면 플레이북을 실행하기 전에
1단계의 IP·계정·키로 SSH 접속이 되는지 확인합니다.

프로젝트의 Ansible 디렉터리에서 실행합니다. ``ansible.cfg`` 에는 인벤토리와 SSH 키 경로가 설정돼 있어야 합니다.

.. code-block:: bash

   source ~/venv-kubespray/bin/activate
   cd ~/openinfra-lab-kit/ansible
   ansible all -m ping
   ansible-playbook prepare-nodes.yml
   ansible-playbook prepare-nodes.yml

플레이북을 두 번 실행하는 것은 반복 적용 결과를 확인하기 위한 절차입니다.
두 번째 실행 전 첫 번째 결과에서 오류가 없는지 확인합니다.
``ok`` 는 성공한 작업, ``changed`` 는 설정을 바꾼 작업,
``unreachable`` 은 접속할 수 없었던 대상, ``failed`` 는 실패한 작업을 나타냅니다.
작업 수는 플레이북 버전에 따라 달라지므로 아래 기록의 숫자와 무조건 같아야 하는 것은 아닙니다.

네 노드가 모두 ``pong`` 을 반환한 뒤 플레이북으로 swap 비활성화, ``overlay`` 와 ``br_netfilter`` 모듈 로드,
IPv4 포워딩과 호스트 이름 설정을 적용했습니다. 노드에서 시간 동기화도 확인했습니다.
두 번째 실행 결과는 네 대 모두 ``ok=9 changed=0 unreachable=0 failed=0`` 이었습니다.
같은 설정을 다시 적용했을 때 추가로 바뀐 항목은 없었습니다.