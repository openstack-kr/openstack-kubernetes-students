.. _verification:

============
검증 (6단계)
============
.. warning::

   이 장은 구현된 검증 스크립트의 실행 방법과 검사 범위를 설명합니다.
   실제 환경에서의 검증 성공 결과를 보고하는 문서는 아닙니다.
   실행 후 성공·실패 여부와 로그를 별도로 기록합니다.

.. _verification:

검증과 상태 수집 (6단계에 해당하는 별도 실행)
==========================================================================================

배포 점검 후 API 기능과 비교용 최종 상태를 확인합니다.
``make stage-6`` 나 ``make verify`` 대상은 없으며 아래 스크립트를 직접 실행합니다.

서비스 동작 검증
------------------------------------------------------------------------------------------

.. code-block:: bash

   bash evaluation/verify-services.sh logs/run-01/verify

``run-01`` 은 실제 배포 기록 번호와 맞춥니다.
인자를 생략하면 ``logs/verify`` 를 사용합니다.
스크립트는 Kubernetes Secret에서 인증 정보를 읽고 로컬 port-forward를 통해 API에
접속합니다. OpenStack CLI는 ``~/venv-openstack/bin/openstack`` 을 사용합니다.

.. list-table:: 검사 내용
   :header-rows: 1

   * - 서비스
     - 구현된 검사
   * - Keystone
     - API 응답과 토큰 발급
   * - Glance
     - 작은 테스트 데이터를 이미지로 등록·업로드하고 active 확인 후 삭제
   * - Neutron
     - 테스트 네트워크 생성·조회·삭제, 등록된 에이전트의 alive와 admin_state_up
   * - Nova
     - nova-compute 두 개 및 하이퍼바이저 두 개의 up/enabled
   * - Placement
     - 자원 제공자 두 개

Glance에 넣는 데이터는 부팅 가능한 OS 이미지가 아닙니다.
Neutron 네트워크 상태는 출력하지만 특정 상태값과 일치하는지 검사하지는 않습니다.
검증 과정은 이미지와 네트워크를 실제로 생성·삭제하며, 종료 시 남은 테스트 자원과
port-forward 정리를 시도합니다. 실패 후에는 잔여 자원도 확인합니다.

로컬 포트 15000, 19292, 19696, 18774, 18778을 사용하므로 다른 프로세스와 겹치지
않아야 합니다. 상태 수집 스크립트와 동시에 실행하지 않습니다.

최종 상태 수집
------------------------------------------------------------------------------------------

.. code-block:: bash

   bash evaluation/collect-state.sh logs/run-01/final-state

노드, Pod 상태별 개수, Helm 릴리스, 컨테이너 이미지, OpenStack 서비스와
엔드포인트, Nova 컴퓨트 서비스, Placement 자원 제공자 정보를 파일로 남깁니다.
이미지 목록은 Pod 명세의 이미지 문자열이며 실제 실행 이미지 digest를 모두 검증한
결과와 동일하지 않습니다.

.. note::

   ``kubernetes-nodes.txt`` 의 STATUS는 조건의 종류를 출력합니다.
   ``Ready`` 라는 문자열만으로 True 여부를 판단할 수 없습니다.
   실제 노드 상태는 ``kubectl get nodes`` 와 3단계 사후 점검으로 확인하세요.

재현 검증 기록
------------------------------------------------------------------------------------------

회차별로 구현 커밋, 서버 환경, 시작·종료 시각, 실패 단계, 추가 조치, 각 스크립트의
종료 코드와 로그를 남깁니다. 상태 수집 성공과 기능 검증 성공을 구분합니다.
새 환경 반복 구축, 재부팅, 사용자 인스턴스 부팅, Floating IP, Horizon 로그인은
해당 시험을 실제 수행한 뒤 결과를 추가합니다.

구현 근거
------------------------------------------------------------------------------------------

* `evaluation/verify-services.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/evaluation/verify-services.sh>`_
* `evaluation/collect-state.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/evaluation/collect-state.sh>`_