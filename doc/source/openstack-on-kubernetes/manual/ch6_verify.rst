6단계. OpenStack 서비스 동작 확인하기
====================================================6단계. OpenStack 서비스 동작 확인하기
==========================================================================================

이 단계의 목표와 실행 위치
------------------------------------------------------------------------------------------

설치 목록에 서비스가 보이는 것과 실제 기능이 동작하는 것은 다릅니다.
이 단계에서는 인증, 이미지 등록, 네트워크 생성과 서비스 상태를 확인합니다.
먼저 Ubuntu 호스트에서 검증용 Pod를 준비하고, 일부 명령은 그 Pod 안에서 실행합니다.
본문에서 실행 위치가 바뀌는 지점을 확인합니다.


11월 2일에 Helm 배포 상태와 OpenStack API를 확인했습니다. 호스트에서는 클러스터 내부 서비스 이름이
해석되지 않아 ``openstack`` 네임스페이스의 클라이언트 파드 ``osc`` 에서 OpenStack CLI를 실행했습니다.
이 파드는 ``openstack-client:2026.1-ubuntu_noble`` 이미지를 사용하고 관리자 인증 정보를 Kubernetes Secret에서 읽습니다.


검증용 파드와 인증 정보
------------------------------------------------------------------------------------------

``osc`` 는 이 실습에서 OpenStack CLI를 실행하기 위해 만든 Pod 이름입니다.
CLI는 화면의 버튼 대신 명령을 입력해 서비스를 사용하는 방식입니다.
클러스터 안에서 실행하면 내부 서비스 이름으로 API에 접근할 수 있습니다.
API는 프로그램이 서비스에 요청을 보내는 접속 창구이며, 토큰은 요청에 사용하는 인증 정보입니다.
Secret은 Kubernetes에서 비밀번호 등 민감한 설정을 전달할 때 사용하는 자원입니다.

``kubectl exec`` 는 이미 실행 중인 Pod 안에서 명령을 실행합니다.
``-- sh`` 로 셸에 들어간 뒤에는 명령이 호스트가 아니라 Pod 안에서 실행됩니다.

직접 테스트 자원 만들기
------------------------------------------------------------------------------------------

호스트에서 팀의 검증용 매니페스트를 ``osc.yaml`` 로 준비합니다. 매니페스트에서 참조하는
관리자 Secret이 같은 네임스페이스에 있어야 합니다. 기존 ``osc`` 가 실행 중이면 첫 줄은 건너뜁니다.

.. code-block:: bash

   kubectl apply -n openstack -f osc.yaml
   kubectl wait -n openstack --for=condition=Ready pod/osc --timeout=180s
   kubectl exec -it -n openstack osc -- sh

이제 프롬프트는 파드 내부입니다. 아래는 테스트 자원을 새로 만들어 상태를 확인하는 예시입니다.
팀이 기록한 검증 항목에 맞춰 작성했으며, 이미지 이름과 네트워크 이름에는 실행 시각을 붙입니다.

.. code-block:: sh

   openstack token issue >/dev/null && echo "인증 성공"
   stamp=$(date +%Y%m%d%H%M%S)
   dd if=/dev/zero of=/tmp/lab-check-$stamp.raw bs=1M count=1
   openstack image create "lab-check-$stamp" --file "/tmp/lab-check-$stamp.raw" --disk-format raw --container-format bare
   openstack image show "lab-check-$stamp" -c status
   openstack network create "lab-check-$stamp"
   openstack network show "lab-check-$stamp" -c status
   openstack network agent list
   openstack compute service list
   openstack hypervisor list

``dd`` 로 만드는 파일은 시험용 데이터이며 부팅 가능한 운영체제가 아닙니다.
따라서 이미지 등록 성공은 VM 부팅 성공을 의미하지 않습니다.
``stamp`` 는 이번 실행의 시각을 담은 변수입니다. 생성과 정리 명령은 같은 Pod 셸에서
진행해야 같은 이름의 자원을 가리킵니다.

이미지는 ``active``, 네트워크는 ``ACTIVE`` 인지 확인합니다. Placement CLI 확장이 설치된 환경에서는
``openstack resource provider list`` 로 두 컴퓨트 노드의 등록도 확인합니다. 결과를 기록한 뒤
방금 만든 테스트 자원만 정리하고 호스트 터미널로 돌아옵니다.

.. code-block:: sh

   openstack network delete "lab-check-$stamp"
   openstack image delete "lab-check-$stamp"
   rm "/tmp/lab-check-$stamp.raw"
   exit

배포 상태
------------------------------------------------------------------------------------------

.. code-block:: bash

   helm list -n openstack --all
   kubectl get pods -n openstack -o wide

릴리스 11개 모두 ``deployed`` 였습니다. 파드는 ``Completed`` 41개, ``Running`` 30개였고,
실행 중인 파드의 컨테이너는 모두 준비 상태였습니다. 여기에는 검증용 ``osc`` 도 포함됩니다.
다시 확인할 때는 파드 수와 함께 Job의 완료 여부와 실행 중인 파드의 READY 열을 봅니다.

서비스별 확인 결과
------------------------------------------------------------------------------------------

* **Keystone** — 관리자 토큰을 발급받았습니다.
* **Glance** — 1 MB 테스트 파일을 이미지로 등록했고 상태는 ``active`` 였습니다. 부팅 가능한 OS 이미지는 사용하지 않았습니다.
* **Neutron** — 생성한 네트워크가 ``ACTIVE`` 였습니다. OVS 에이전트 3개와 L3·DHCP·Metadata 에이전트 각 1개가 모두 살아 있었습니다.
* **Nova** — conductor, scheduler와 두 compute 서비스가 ``enabled`` 및 ``up`` 이었습니다. 하이퍼바이저도 두 대 모두 ``up`` 이었습니다.
* **Placement** — ``compute-1`` 과 ``compute-2`` 가 리소스 제공자로 등록돼 있었습니다.

아래는 기존 ``osc`` 파드에서 다시 조회하는 예입니다. 이미지 등록과 네트워크 생성은 별도의 생성 작업으로 검증했습니다.

.. code-block:: bash

   kubectl -n openstack exec osc -- sh -c 'openstack token issue >/dev/null' && echo 'token OK'
   kubectl -n openstack exec osc -- openstack image list
   kubectl -n openstack exec osc -- openstack network list
   kubectl -n openstack exec osc -- openstack network agent list
   kubectl -n openstack exec osc -- openstack compute service list
   kubectl -n openstack exec osc -- openstack hypervisor list

검증 범위
------------------------------------------------------------------------------------------

서비스 카탈로그의 내부 엔드포인트를 호출한 결과는 Nova 401, Neutron 200, Keystone 200, Placement 200,
Glance 300이었습니다. Nova의 401은 인증이 필요한 API가 응답한 결과입니다. 이 호출은 클러스터 내부
서비스 주소로 연결됐으므로 외부 접속이나 Ingress를 통한 접근까지 확인한 것은 아닙니다.

핵심 파드 22개의 최근 30분 로그에서 미리 정한 오류 문자열이 발견된 줄은 0개였습니다.
이번에 확인한 범위는 서비스 등록과 개별 API 동작까지입니다. 인스턴스 부팅, 인스턴스의 네트워크 연결,
재부팅 후 복구는 아직 검증하지 않았습니다.

검증 결과를 해석할 때
------------------------------------------------------------------------------------------

HTTP 상태 코드가 반환되었다는 사실은 API가 요청에 응답했다는 근거입니다.
그 코드만으로 모든 기능과 인증이 정상이라고 판단하지 않습니다.
또한 특정 오류 문자열을 찾지 못했다는 결과는 검사한 시간과 문자열 범위에 한정됩니다.
새 실행 결과에는 시각과 대상, 사용한 명령, 성공 여부를 함께 남깁니다.