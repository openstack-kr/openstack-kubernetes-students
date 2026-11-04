.. _openstack-deploy:

======================================
OpenStack 배포 (5단계: OpenStack-Helm)
======================================

4단계 점검을 통과한 Kubernetes 클러스터에 Helm으로 OpenStack을 설치합니다.

실행 전 확인
------------------------------------------------------------------------------------------

.. warning::

   기준 커밋의 ``stage5/preflight.sh`` 는 values 파일을 11개로 검사하지만
   ``stage5/values`` 에는 Horizon을 포함해 12개가 있습니다.
   따라서 그대로 실행하면 사전 점검에서 중단될 수 있습니다.
   파일을 임의로 삭제하지 말고 배포 대상과 검사 기준을 함께 수정해야 합니다.

노드 Ready, ``openstack`` 네임스페이스, ``general`` 스토리지클래스와
노드 라벨을 확인합니다. 차트의 기본값과 저장소의 values를 함께 검토합니다.

배포 순서와 설정
------------------------------------------------------------------------------------------

.. code-block:: bash

   make stage-5

배포 순서는 RabbitMQ → MariaDB → Memcached → ingress-nginx → Keystone →
Glance → Open vSwitch → libvirt → Placement → Nova → Neutron → Horizon입니다.
네임스페이스는 모두 ``openstack`` 입니다.

각 릴리스는 ``stage5/values/values-서비스명.yaml`` 을 사용합니다.
OpenStack-Helm 차트에는 ``2026.1`` 과 ``ubuntu_noble`` override를 먼저 적용하고,
프로젝트 values를 나중에 적용합니다. ingress-nginx는 별도 저장소의 차트입니다.

OpenStack-Helm 차트 버전은 ``stage4/chart-versions.env`` 에서 읽고
``+c665eedfa`` 접미사를 붙입니다. ingress-nginx 차트 버전 ``4.8.3`` 은
배포 스크립트에 지정되어 있습니다.
이미지 설정에는 고정 태그와 digest가 사용됩니다. 실제 적용된 전체 이미지 목록은
배포 후 :doc:`verification` 의 상태 수집 결과로 확인합니다.

배포 스크립트는 ``helm upgrade --install`` 을 호출합니다.
모든 Pod가 Ready가 될 때까지 자동 대기하는 ``--wait`` 옵션은 사용하지 않습니다.
명령 제출 직후의 점검은 아직 시작 중인 Pod 때문에 실패할 수 있으므로
이벤트와 준비 상태를 보고 실제 실패인지 판단합니다.

배포 확인
------------------------------------------------------------------------------------------

.. code-block:: bash

   helm list -n openstack --all
   kubectl get pods -n openstack -o wide
   kubectl get events -n openstack --sort-by=.metadata.creationTimestamp
   bash stage5/postcheck.sh

사후 점검은 릴리스 12개의 ``deployed``, 완료된 작업을 제외한 Pod의 READY,
ingress 컨트롤러, 컴퓨트 두 노드의 libvirt와 nova-compute, Nova의 ``virt_type=qemu``,
Horizon Pod와 ``horizon-int`` 의 80번 포트를 확인합니다.
이 점검만으로 API 기능이나 웹 로그인 성공을 확정하지 않습니다.
다음 :doc:`verification` 에서 서비스 동작을 별도로 검사합니다.


구현 근거
------------------------------------------------------------------------------------------

* `stage5/preflight.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage5/preflight.sh>`_
* `stage5/deploy.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage5/deploy.sh>`_
* `stage5/postcheck.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage5/postcheck.sh>`_
* `stage5/values <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage5/values>`_
* `stage4/chart-versions.env <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage4/chart-versions.env>`_