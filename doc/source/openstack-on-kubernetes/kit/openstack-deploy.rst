.. _openstack-deploy:

OpenStack 배포 (5단계: OpenStack-Helm)
==========================================================================================

이 장을 읽기 전에
------------------------------------------------------------------------------------------

배포는 준비한 프로그램과 설정을 실제 환경에 설치해 실행시키는 작업입니다.
이 단계에서는 Helm을 이용해 OpenStack과 지원 서비스를 Kubernetes에 설치합니다.
차트는 설치 구성의 묶음이고, values는 실습 환경에 맞추어 지정하는 값입니다.
설치한 차트의 개별 배포를 릴리스라고 합니다.
명령은 Ubuntu 호스트에서 실행하며 결과는 ``openstack`` 네임스페이스에서 확인합니다.


4단계 점검을 통과한 Kubernetes 클러스터에 Helm으로 OpenStack을 설치합니다.

실행 전 확인
------------------------------------------------------------------------------------------

사전 점검의 values 파일 개수 기준은 Horizon을 포함한 **12개** 로 수정되었습니다.
성공 메시지에는 아직 ``11 Stage 5 values files found`` 라는 이전 문구가 남아 있지만
실제 비교 조건은 12개입니다. 파일을 삭제하여 메시지의 숫자에 맞추지 않습니다.

노드 Ready, ``openstack`` 네임스페이스, ``general`` 스토리지클래스와
노드 라벨을 확인합니다. 차트의 기본값과 저장소의 values를 함께 검토합니다.


지원 서비스와 OpenStack 서비스
------------------------------------------------------------------------------------------

RabbitMQ는 서비스 사이의 메시지를 전달하고, MariaDB는 데이터를 저장하며,
Memcached는 일부 정보를 임시로 보관합니다. Keystone은 인증, Glance는 이미지,
Nova는 컴퓨트, Neutron은 네트워크를 담당합니다. Horizon은 웹 화면을 제공합니다.
여러 서비스가 함께 동작하므로 한 릴리스의 성공만으로 전체 설치를 판단하지 않습니다.

``override`` 는 기본 설정에 덧씌우는 값입니다. 파일을 여러 개 적용할 때는 적용 순서가
결과에 영향을 주므로 실제 배포 코드의 순서를 유지합니다.

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

배포 스크립트는 ``helm upgrade --install`` 을 호출하며 Helm의 ``--wait`` 옵션은
사용하지 않습니다. 대신 ``make stage-5`` 는 배포 후 ``stage5/wait-ready.sh`` 를
실행하여 ``postcheck.sh`` 가 통과할 때까지 약 30초 간격으로 재점검합니다.
제한값은 1200초(20분)이며, 개별 점검 명령 자체의 실행 시간까지 강제로 제한하는
방식은 아니므로 실제 종료 시각이 정확히 20분으로 보장되지는 않습니다.
제한을 넘기면 실패로 끝납니다. 이벤트와 컨테이너 로그를 확인한 뒤 재점검합니다.

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
전체 배포는 다음 6단계 검증으로 이어집니다. 5단계만 실행했다면
:doc:`verification` 의 ``make stage-6`` 으로 서비스 동작과 최종 상태를 확인합니다.


구현 근거
------------------------------------------------------------------------------------------

* `stage5/preflight.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage5/preflight.sh>`_
* `stage5/deploy.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage5/deploy.sh>`_
* `stage5/postcheck.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage5/postcheck.sh>`_
* `stage5/values <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage5/values>`_
* `stage4/chart-versions.env <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage4/chart-versions.env>`_