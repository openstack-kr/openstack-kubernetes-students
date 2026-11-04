==============
Helm 핵심 개념
==============

OpenStack 을 Kubernetes 위에 올릴 때 반복해서 등장하는 전제 도구입니다.
Helm 은 Kubernetes 애플리케이션의 패키징·배포를 선언적으로 다룹니다. 도구
자체의 상세는 공식 문서로 링크하고, 여기서는 "이 개념이 OpenStack·Kubernetes
결합에서 무엇에 쓰이는가"에 초점을 둡니다.

.. note::

   기여자 작업용 골격입니다. 도구 사용법을 재설명하지 말고, 각 개념이
   OpenStack·Kubernetes 결합의 어디에 쓰이는지(왜 알아야 하는지)를 한 줄로
   유지하세요. 상세는 공식 문서와 해당 섹션으로.

.. warning::

   **아래는 추가한 내용. 검토 후 기존 내용 삭제 필요.**

OpenStack 서비스 하나를 Kubernetes에 배포할 때도 Deployment, Service,
Secret 등 여러 리소스가 필요합니다. Helm은 이 리소스들을 차트로 묶고
환경별 설정을 적용하여 설치와 변경을 관리합니다.

이 프로젝트에서는 OpenStack-Helm이 제공하는 차트에 실습 환경의
values를 적용하여 OpenStack 서비스와 지원 구성요소를 배포합니다.

차트, values, 릴리스
------------------------------------------------------------

.. list-table:: Helm 개념과 프로젝트에서의 역할
   :header-rows: 1
   :widths: 15 40 45

   * - 용어
     - 의미
     - 이 프로젝트에서의 사용
   * - Chart
     - Kubernetes 리소스 템플릿과 기본 설정을 묶은 패키지
     - Keystone, Nova 등 서비스별 배포 구성을 제공
   * - values
     - 템플릿에 전달하는 설정값
     - 이미지, 노드 배치, 저장소 등 실습 환경의 설정을 지정
   * - Release
     - 차트를 특정 이름과 설정으로 설치한 개별 배포
     - ``openstack`` 네임스페이스의 ``keystone``, ``nova`` 등
   * - Revision
     - 릴리스의 설치·업데이트 등에 따른 이력 번호
     - 설정 변경 전후의 배포 이력을 확인
   * - Repository
     - 차트를 찾아 내려받는 저장소
     - 배포할 OpenStack-Helm 차트와 버전을 선택

같은 차트도 릴리스 이름과 values를 달리하여 여러 번 설치할 수 있습니다.
여러 values 파일을 적용하면 뒤에 지정한 파일의 값이 우선하므로,
사용한 파일과 적용 순서를 함께 기록합니다.

.. code-block:: text

   차트 템플릿 + 기본 values + 실습 환경 values
                         ↓ 렌더링
                Kubernetes 매니페스트
                         ↓ Helm으로 배포
                Kubernetes 리소스 생성

   Helm은 이 배포를 릴리스 이름과 변경 이력으로 관리

Helm과 OpenStack-Helm의 관계
------------------------------------------------------------

Helm은 차트를 설치하고 관리하는 도구입니다.
OpenStack-Helm은 OpenStack 서비스와 지원 구성요소를 Kubernetes에
배포하기 위한 차트와 관련 구성을 제공하는 프로젝트입니다.

이 실습의 ``stage5/deploy.sh`` 는 Helm 명령으로 서비스별 차트를 배포하고,
``stage5/values/`` 의 설정 파일을 적용합니다.
예를 들어 ``values-keystone.yaml`` 은 Keystone 배포에 사용할
실습 환경의 설정을 담습니다.

차트 버전, 컨테이너 이미지 버전, OpenStack 릴리스는 서로 다른 정보입니다.
차트 버전만 기록하지 말고 실제 적용한 values와 이미지도 함께 확인합니다.

배포 상태와 서비스 동작의 차이
------------------------------------------------------------

Helm 릴리스가 ``deployed`` 상태라고 해서 모든 Pod와 OpenStack API가
정상 동작한다고 단정할 수는 없습니다. 다음 세 수준을 구분하여 확인합니다.

.. list-table:: 배포 후 확인할 대상
   :header-rows: 1

   * - 확인 대상
     - 확인하는 내용
   * - Helm 릴리스
     - 차트 배포 상태와 변경 이력
   * - Kubernetes 리소스
     - Pod 준비 상태, Job 완료 여부와 이벤트
   * - OpenStack 서비스
     - 인증 토큰 발급 등 실제 API 기능

다음은 ``openstack`` 네임스페이스에 ``keystone`` 릴리스가 있을 때
배포 상태를 조회하는 예시입니다.

.. code-block:: bash

   helm list -n openstack --all
   helm status keystone -n openstack
   helm history keystone -n openstack
   kubectl get pods -n openstack

설치 전에는 ``helm template`` 으로 values를 적용한 매니페스트를
확인할 수 있습니다. 다만 렌더링 성공이 실제 클러스터에서의
배포 성공을 보장하지는 않습니다.

변경과 복구
------------------------------------------------------------

차트와 values의 변경은 릴리스 업데이트로 관리합니다.
변경 전후의 차트 버전, values와 릴리스 이력을 남겨야
문제 발생 시 어떤 설정이 달라졌는지 확인할 수 있습니다.

롤백은 이전 릴리스 구성으로 돌아가는 데 사용하지만,
DB 스키마나 저장된 데이터까지 자동으로 복구하는 기능은 아닙니다.
데이터 백업과 복구는 별도로 준비합니다.

실습 문서와 연결하기
------------------------------------------------------------

* :doc:`/openstack-on-kubernetes/kit/prereq-components`
  에서 Helm 배포에 필요한 노드 라벨과 저장소 준비를 확인합니다.
* :doc:`/openstack-on-kubernetes/kit/openstack-deploy`
  에서 차트와 values를 적용하는 실제 배포 순서를 확인합니다.
* :doc:`/openstack-on-kubernetes/kit/verification`
  에서 배포 이후 OpenStack 서비스 기능을 검사합니다.

참고 문서
------------------------------------------------------------

* `Helm 차트 <https://helm.sh/docs/topics/charts/>`_
* `OpenStack-Helm <https://docs.openstack.org/openstack-helm/latest/>`_

공식 문서의 명령과 옵션은 실습에서 사용하는 Helm 및 차트 버전과
대조합니다.