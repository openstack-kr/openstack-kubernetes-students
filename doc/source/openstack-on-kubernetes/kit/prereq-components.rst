.. _prereq-components:

선행 요소 (4단계)
==========================================================================================

이 장을 읽기 전에
------------------------------------------------------------------------------------------

OpenStack을 설치하기 전에 사용할 이름 공간, 실행할 노드, 저장 공간을 준비합니다.
네임스페이스는 자원을 묶어 관리하는 범위이고, 노드 라벨은 배치 대상을 선택하는 표시입니다.
StorageClass는 저장 공간을 어떤 방식으로 제공할지 정하는 설정입니다.
명령은 Ubuntu 호스트의 구현 저장소 최상위에서 실행합니다.


Kubernetes 설치 후 OpenStack 서비스의 배치 조건과 저장소를 준비합니다.


접속 설정과 저장 공간 이해하기
------------------------------------------------------------------------------------------

kubeconfig는 kubectl과 Helm이 사용할 클러스터 주소와 인증 정보를 담는 파일입니다.
새 파일로 교체하면 명령이 바라보는 클러스터가 달라질 수 있어 현재 파일을 확인합니다.
프로비저너는 저장 공간 요청을 처리하는 프로그램입니다.
local-path는 해당 노드의 디스크를 사용하며 여러 노드에 데이터를 자동 복제하는 저장소가 아닙니다.

실행과 변경 대상
------------------------------------------------------------------------------------------

.. code-block:: bash

   make stage-4

준비, 노드 설정, 저장소 설정, 사후 점검을 순서대로 실행합니다.

* cp의 관리자 kubeconfig를 임시 파일로 가져온 뒤 파일이 비어 있지 않은지와
  ``kubectl config view`` 로 읽을 수 있는지 확인합니다. 실패하면 기존 설정을 유지하고
  중단합니다. 성공하면 권한을 600으로 설정하고 ``~/.kube/config`` 를 교체합니다.
  다른 클러스터 설정을 보관하고 있다면 먼저 백업합니다.
* 새 kubeconfig를 준비한 다음 4단계 사전 점검을 수행합니다.
  파일 형식 검사 성공과 실제 API 접속 성공은 서로 다른 확인 항목입니다.
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


참고 코드
------------------------------------------------------------------------------------------

* `stage4/prepare.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage4/prepare.sh>`_
* `stage4/configure-nodes.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage4/configure-nodes.sh>`_
* `stage4/configure-storage.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage4/configure-storage.sh>`_
* `stage4/postcheck.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage4/postcheck.sh>`_