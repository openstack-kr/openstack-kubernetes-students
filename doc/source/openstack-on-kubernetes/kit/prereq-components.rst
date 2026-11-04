.. _prereq-components:

=================
선행 요소 (4단계)
=================

Kubernetes 설치 후 OpenStack 서비스의 배치 조건과 저장소를 준비합니다.

실행과 변경 대상
------------------------------------------------------------------------------------------

.. code-block:: bash

   make stage-4

준비, 노드 설정, 저장소 설정, 사후 점검을 순서대로 실행합니다.

* cp의 관리자 kubeconfig를 호스트 ``~/.kube/config`` 로 가져옵니다.
  기존 파일이 덮어써지므로 다른 클러스터 설정을 보관하고 있다면 먼저 백업합니다.
* OpenStack-Helm 저장소와 ``osh`` Helm 플러그인을 준비합니다.
* ``~/openstack-helm`` 을 지정 커밋에 맞춥니다. 다른 커밋이나 일반 폴더이면
  제거 후 다시 받을 수 있으므로 이 경로의 개인 수정본은 미리 별도 보관합니다.
* ``openstack`` 네임스페이스와 노드 라벨을 설정합니다.
* Kubespray addons 설정을 변경하고 ``cluster.yml`` 을 다시 실행하여 local-path를 구성합니다.

노드 라벨과 저장소
------------------------------------------------------------------------------------------

``ctrl-worker`` 에는 ``openstack-control-plane=enabled`` 와 ``openvswitch=enabled`` 를,
``compute-1``, ``compute-2`` 에는 ``openstack-compute-node=enabled`` 와
``openvswitch=enabled`` 를 붙입니다.
Kubernetes 컨트롤 플레인인 ``cp`` 와 OpenStack 제어 서비스를 두는 ``ctrl-worker`` 는
서로 다른 역할입니다.

스토리지클래스 이름은 ``general``, provisioner는 ``rancher.io/local-path`` 입니다.
노드 로컬 디스크를 사용하므로 노드 장애 시 데이터 접근이 중단될 수 있으며,
디스크 손상이나 삭제로 데이터가 유실될 수 있습니다.

.. note::

   현재 ``configure-storage.sh`` 는 ``stage4/config/addons.yml`` 의 존재를 확인하지만
   내용을 읽어 그대로 적용하지는 않습니다. 활성화 값과 ``general`` 이름을 스크립트에서
   지정합니다. 해당 YAML만 수정하여 설정이 바뀐다고 판단하지 마세요.
   ``OSH_PLUGIN_VERSION`` 도 선언되어 있지만 설치·사후 검사에서 그 버전을 강제하지 않습니다.

확인
------------------------------------------------------------------------------------------

.. code-block:: bash

   bash stage4/postcheck.sh
   kubectl get nodes -L openstack-control-plane,openstack-compute-node,openvswitch
   kubectl get storageclass general
   kubectl get pods -n local-path-storage
   helm plugin list

API, 네임스페이스, 라벨, 저장소, Helm 준비 상태를 확인한 뒤
:doc:`openstack-deploy` 로 이동합니다.


구현 근거
------------------------------------------------------------------------------------------

* `stage4/prepare.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage4/prepare.sh>`_
* `stage4/configure-nodes.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage4/configure-nodes.sh>`_
* `stage4/configure-storage.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage4/configure-storage.sh>`_
* `stage4/postcheck.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage4/postcheck.sh>`_