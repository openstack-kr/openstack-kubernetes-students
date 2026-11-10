문제 해결 기록
==========================================================================================

문제를 확인하는 순서
------------------------------------------------------------------------------------------

오류가 발생하면 마지막으로 성공한 단계와 실패한 명령부터 확인합니다.
그다음 실행 위치가 호스트인지, 노드 VM인지, Pod 안인지 확인합니다.
같은 명령을 반복하거나 설정을 여러 개 동시에 바꾸기 전에 원래 오류 메시지를 보관합니다.
아래는 당시의 문제 해결 기록이며 모든 환경에서 같은 원인이 생긴다는 뜻은 아닙니다.


단계별로 막혔던 부분과 확인 방법을 정리했습니다.


자주 보이는 상태 표시
------------------------------------------------------------------------------------------

``Permission denied`` 는 접근 권한이 거부됐다는 뜻입니다.
``Pending`` 은 Pod 배치나 저장 공간 연결 등이 아직 완료되지 않은 상태입니다.
``Init`` 은 초기화 컨테이너가 아직 끝나지 않았음을 나타낼 수 있습니다.
``Running`` 인 Pod도 일부 컨테이너가 준비되지 않을 수 있으므로 READY를 확인합니다.
``Completed`` 는 작업이 정상적으로 끝난 Pod에 표시될 수 있어 그 자체로 오류가 아닙니다.

VM 시작 중 Permission denied
------------------------------------------------------------------------------------------

Terraform이 디스크를 생성했지만 VM을 시작하지 못했습니다. 먼저 오류에 나온 디스크 경로와
상위 디렉터리의 접근 권한을 확인하고, 같은 시각의 AppArmor 로그와 프로파일을 확인합니다.

.. code-block:: bash

   namei -l /var/lib/libvirt/images
   ls -l /var/lib/libvirt/images
   sudo journalctl -k --no-pager | grep -i apparmor
   sudo aa-status
   virsh list --all

임시로 변경했던 libvirt 보안 설정을 원복하고 ``/etc/apparmor.d/local/abstractions/libvirt-qemu`` 에
실습 디스크 경로에 대한 규칙 ``/var/lib/libvirt/images/** rwk,`` 을 추가했습니다. 규칙 적용 후 VM 네 대가
실행됐고 QEMU 프로세스 네 개에 AppArmor 프로파일이 적용된 것을 확인했습니다.
실패 당시 커널 로그에서 ``DENIED`` 는 확인하지 못했습니다. 규칙을 제거한 대조 실험도 수행하지 않아 원인을 한 가지로 단정하기 어렵습니다.

배포 중 증상별 확인
------------------------------------------------------------------------------------------

* **NTP 동기화 실패** — 호스트의 chrony 상태와 아웃바운드 UDP 123 정책을 확인합니다. 이번에는 방화벽 정책 변경 후 동기화됐습니다.
* **노드 이름이 127.0.1.1로 해석됨** — 인벤토리에서 ``ansible_host``, ``ip``, ``access_ip`` 가 각 VM의 주소인지 확인합니다.
* **PVC가 Pending 상태** — ``general`` 의 바인딩 모드는 ``WaitForFirstConsumer`` 입니다. PVC를 사용하는 파드가 어느 노드에 배치됐는지 함께 봅니다.
* **Keystone 404** — 생성된 Ingress와 컨트롤러의 클래스가 일치하는지 확인합니다. DNS 문제는 파드 안에서 서비스 이름이 가리키는 주소를 확인해 구분합니다.
* **Glance 설치 시간 초과** — 실패한 bootstrap Job의 로그에서 이미지 다운로드 실패를 확인했습니다.
* **libvirt·nova-compute가 Init 상태** — Neutron 배포 여부부터 확인합니다. ``helm list`` 의 상태와 파드의 준비 상태를 따로 봅니다.

5단계에서 적용한 설정은 :doc:`ch5_openstack` 에 정리했습니다.

인스턴스는 ACTIVE인데 DHCP 주소를 받지 못함
------------------------------------------------------------------------------------------

11월 3~4일에는 인스턴스가 실행되어도 콘솔 로그에 ``169.254.x.x`` 주소가 나타났습니다.
정상적인 DHCP 임대를 받지 못하고 임시 주소를 사용한 상태였습니다.
OVS 터널의 오류에는 ``Address already in use`` 가 기록됐습니다.
이 환경에서는 Calico VXLAN이 UDP 4789를 사용하여 Neutron OVS의 VXLAN과 충돌했습니다.
다른 환경에서도 같은 포트를 쓴다고 가정하지 말고 실제 설정을 확인합니다.

호스트에서 인스턴스 로그와 네트워크 에이전트 상태부터 확인합니다.

.. code-block:: bash

   kubectl -n openstack exec osc -- openstack console log show demo-vm1
   kubectl -n openstack exec osc -- openstack network agent list
   kubectl get pods -n openstack -o wide
   helm history neutron -n openstack

해당 노드의 OVS Pod와 컨테이너를 확인한 다음, 그 안에서 ``ovs-vsctl list Interface`` 로
VXLAN 인터페이스 이름을 찾고 ``options``, ``statistics``, ``error`` 를 확인합니다.
인터페이스 이름은 실행 환경마다 달라 고정된 이름을 복사해 쓰지 않습니다.

기록에서는 Neutron OVS 에이전트의 VXLAN 포트를 4790으로 바꾸고 기존 설정을
유지하는 Helm 업데이트를 적용했습니다. 결과는 Neutron 리비전 3이었으며,
터널의 ``dst_port="4790"`` 과 DHCP 로그의 ``leased 10.10.10.51`` 을 확인했습니다.
원본 설정은 ``values-neutron-vxlan4790.yaml`` 에 보관했습니다.
PDF에는 YAML 전문이 없으므로 적용할 키와 기존 values의 병합 순서는 해당 파일 및
서버 기록에서 확인해야 합니다. 서비스 상태를 보지 않고 포트 숫자만 바꾸지 않습니다.

당시 neutron-ovs-agent Pod 두 개도 ``0/1`` 에서 ``1/1`` 로 회복됐으나,
준비 상태 변화의 직접 원인은 별도로 확정하지 못했습니다.
인스턴스의 부팅 직후 메타데이터 오류도 포트 변경 후 재검증하지 않았습니다.

DNS를 수정했는데 Glance가 다시 재시작함
------------------------------------------------------------------------------------------

11월 4일에는 Glance API가 반복 재시작하고 Keystone 응답이 지연됐습니다.
노드에서 검색 도메인을 수정했어도 이전에 만들어진 Pod는 ``/etc/resolv.conf`` 에
``lab.local`` 을 유지하고 있었습니다. 검색 도메인은 짧은 이름의 뒤에 붙여
DNS 주소를 찾을 때 사용하는 목록입니다.

기록에서는 잘못된 DNS 응답으로 Keystone이 MariaDB 대신 외부 주소에 연결하려 했고,
DB 연결 시간 초과와 인증 지연이 이어졌습니다. Glance의 상태 점검도 시간 초과되어
컨테이너가 종료됐습니다. 종료 코드 137만 보고 메모리 부족으로 단정하지 않고,
Pod 이벤트·종료 사유·같은 시각의 서비스 로그를 함께 확인합니다.

먼저 문제가 발생한 Pod 안의 ``/etc/resolv.conf`` 와 서비스 이름의 해석 결과를
확인합니다. 노드 DNS 수정이 반영됐는지 확인한 뒤 영향받은 API Deployment만
순서대로 재시작했습니다. 아래는 그 조치를 다시 수행할 때의 예시입니다.
재시작 중 API 요청에 영향이 있을 수 있으므로 서비스 이용 상황을 확인합니다.

.. code-block:: bash

   kubectl -n openstack rollout restart deployment/keystone-api
   kubectl -n openstack rollout status deployment/keystone-api --timeout=300s
   kubectl -n openstack rollout restart deployment/glance-api
   kubectl -n openstack rollout status deployment/glance-api --timeout=300s
   kubectl -n openstack rollout restart deployment/placement-api
   kubectl -n openstack rollout status deployment/placement-api --timeout=300s

한 서비스의 준비가 실패하면 다음 재시작을 진행하지 말고 원인을 확인합니다.
새 Pod에서 ``lab.local`` 제거, MariaDB 주소 해석, 토큰 발급과 이미지 등록을
다시 확인합니다. 오래된 Pod를 모두 일괄 삭제하는 절차는 아닙니다.

당시 조치 후 ``evaluation/verify-services.sh`` 는 3회 연속 ``PASS 15 / FAIL 0`` 이었고,
이미지 생성·삭제도 3회 성공했습니다. 이는 같은 수동 구축 환경의 조치 후 검사이며
새 서버 전체 구축을 3회 성공했다는 뜻이 아닙니다. 30분 안정성 확인 결과는 기록에 없습니다.

Helm이 로컬 차트 폴더를 잘못 읽음
------------------------------------------------------------------------------------------

``missing in charts/ directory: helm-toolkit`` 오류가 발생했을 때는 현재 폴더의
``openstack-helm/`` 소스 폴더가 원격 저장소 차트 대신 선택되는지 확인합니다.
이 사례에서는 해당 폴더가 없는 ``/tmp`` 로 이동해 해결했습니다.
이동 후에도 values 파일은 절대 경로로 지정하고 차트 버전을 고정합니다.

``helm osh get-values-overrides`` 는 ``-p`` 로 원본 overrides 폴더를 지정합니다.
예를 들어 이 환경의 소스 폴더는 ``~/openstack-helm/values_overrides`` 입니다.
필요한 overrides가 있는 차트인데 조회 결과가 비었다면 설치를 중단하고 경로를
확인합니다. 원래 해당 overrides가 없는 차트까지 같은 기준으로 실패 처리하지 않습니다.

Horizon 화면이 열리지 않음
------------------------------------------------------------------------------------------

``ERR_CONNECTION_RESET`` 또는 SSH의 ``Connection refused`` 가 나타나면
Ubuntu 호스트의 port-forward와 Windows의 SSH 터널이 모두 살아 있는지 확인합니다.
Pod가 바뀌거나 연결이 종료되면 port-forward를 다시 실행해야 할 수 있습니다.
``Address already in use`` 라면 해당 컴퓨터의 8080번 포트를 다른 프로그램이
사용하는지 확인합니다. 접속 순서는 :doc:`ch7_horizon` 을 따릅니다.