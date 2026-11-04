.. _kubernetes:

==================================
Kubernetes 구축 (3단계: Kubespray)
==================================

1~2단계가 끝나고 네 노드에 SSH 접속할 수 있어야 합니다.
Kubespray는 Ansible 플레이북으로 Kubernetes, Calico, containerd를 구성합니다.

실행
------------------------------------------------------------------------------------------

.. code-block:: bash

   make stage-3

사전 점검 → 인벤토리 준비 → 설치 → 사후 점검 순서입니다.
``stage3/prepare.sh`` 는 ``~/kubespray/inventory/openinfra`` 를 새로 준비하고
저장소의 인벤토리와 ``k8s-cluster.yml`` 을 복사합니다.
이 생성 폴더에만 직접 넣은 설정은 재실행 시 사라질 수 있습니다.

주요 설정은 다음과 같습니다.

.. code-block:: yaml

   kube_version: 1.35.4
   kube_network_plugin: calico
   container_manager: containerd

설치 스크립트는 Kubespray의 ``cluster.yml`` 을 실행하고
``logs/stage3-kubespray-날짜-시각.log`` 에 출력을 남깁니다.
Ansible의 실패는 배포 스크립트의 실패로 전달됩니다.

확인
------------------------------------------------------------------------------------------

.. code-block:: bash

   bash stage3/postcheck.sh
   ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 'sudo kubectl get nodes -o wide'
   ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 'sudo kubectl get pods -n kube-system'

사후 점검은 cp에 접속하여 API 응답, 지정 노드 네 대, Ready, 버전 ``v1.35.4``,
containerd 사용 여부와 시스템 Pod의 표시 상태를 확인합니다.
정상 종료한 작업 Pod의 ``Completed`` 는 실패가 아닙니다.
``Running`` 표시는 모든 컨테이너의 Ready를 뜻하지 않으므로 READY 열도 확인합니다.
호스트의 kubeconfig 준비는 다음 :doc:`prereq-components` 에서 수행합니다.


구현 근거
------------------------------------------------------------------------------------------

* `stage3/prepare.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage3/prepare.sh>`_
* `stage3/deploy.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage3/deploy.sh>`_
* `stage3/postcheck.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage3/postcheck.sh>`_
* `stage3/inventory/k8s-cluster.yml <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage3/inventory/k8s-cluster.yml>`_