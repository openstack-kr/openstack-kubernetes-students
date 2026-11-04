================================
OpenInfra Lab Kit 구현 도구의 역할
================================

Lab Kit 구축은 서버 준비, 노드 VM 생성, Kubernetes 설치, OpenStack 배포와
검증으로 이어집니다. 단계마다 조작하는 대상이 달라 여러 도구를 조합합니다.
이 장은 팀 자료 「OpenInfra Lab Kit 구현 도구의 역할」의 0~6단계 표를 바탕으로
각 도구의 담당 범위와 결과를 설명합니다.

단계별 역할
------------------------------------------------------------

.. list-table::
   :header-rows: 1

   * - 단계
     - 도구
     - 담당 작업
     - 확인할 결과
   * - 0. 환경 점검·도구 설치
     - Shell 스크립트
     - 서버 자원·가상화·OS·네트워크·권한 점검과 지정 버전 도구 설치
     - 요구 조건과 도구 버전
   * - 1. 인프라 구성
     - Terraform + libvirt provider
     - 노드 VM 4대와 디스크·NAT 네트워크를 코드로 정의하고 생성
     - VM·디스크·네트워크와 Terraform 상태
   * - 1. 가상화 기반
     - libvirt + QEMU/KVM
     - libvirt가 가상자원을 관리하고 QEMU/KVM이 노드 VM 실행
     - VM 실행과 노드 접속
   * - 2. 노드 사전 설정
     - Ansible
     - VM 내부 swap·커널 모듈·커널 파라미터·이름 해석 등을 설정하고 시간 동기화 확인
     - 노드별 적용 상태와 재실행 결과
   * - 3. Kubernetes 구축
     - Kubespray
     - Ansible을 이용해 Kubernetes·런타임·CNI를 구성하고 노드를 연결
     - 노드 Ready와 시스템 Pod 상태
   * - 4. 선행 요소 구성
     - Helm + Kubernetes 매니페스트
     - 스토리지·접속 경로 등 필요한 요소 구성과 노드 역할 레이블 적용
     - 스토리지와 배치 조건, 필요한 접근 경로
   * - 5. OpenStack 배포
     - OpenStack-Helm + Helm
     - 차트와 values로 OpenStack 및 DB·메시지 큐 등 지원 서비스 배포
     - 릴리스 상태와 서비스 Pod 준비 상태
   * - 6. 검증·상태 수집
     - kubectl · Helm · OpenStack CLI
     - 각 계층의 상태와 구현된 기능 검증 결과·비교용 정보 기록
     - 실행한 항목별 결과와 로그

PDF의 두 1단계 행은 인프라 정의 도구와 실제 VM 실행 기반을 나누어 설명합니다.
가상화 기반이 Terraform이 생성한 VM을 실행하므로 하나의 단계 안에서 연결됩니다.

Ansible의 일반적인 담당 범위에는 호스트명과 시간 서비스 설정도 포함할 수 있습니다.
이 프로젝트의 초기 수동 구축에서는 호스트명을 cloud-init이 정하고,
VM의 systemd-timesyncd 동기화를 확인했습니다.
실제 플레이북이 수행하는 작업은 해당 단계 문서와 코드를 기준으로 봅니다.

도구 사이의 연결
------------------------------------------------------------

.. code-block:: text

   Shell로 서버와 도구 준비
     → Terraform 설정
         → libvirt provider → libvirt → QEMU/KVM → 노드 VM
     → Ansible로 VM 내부 준비
     → Kubespray로 Kubernetes 설치
     → Helm·매니페스트로 선행 요소 구성
     → OpenStack-Helm 차트를 Helm으로 배포
     → kubectl·Helm·OpenStack CLI로 계층별 확인

Terraform은 인프라의 원하는 상태를 코드로 표현하고 실제 자원과 상태 정보를
대조하여 변경을 계획합니다. libvirt provider는 Terraform과 libvirt를 연결합니다.
Ansible은 인벤토리에 등록한 노드에 플레이북 작업을 적용합니다.
Kubespray는 Kubernetes 구축을 위해 마련된 Ansible 기반 프로젝트입니다.

Helm은 차트를 처리하는 도구이며 OpenStack-Helm은 배포할 차트와 구성을 제공합니다.
차트의 상세 개념은 :doc:`helm` 을 참고하세요.

어떤 상태를 어느 도구로 볼까
------------------------------------------------------------

.. list-table::
   :header-rows: 1

   * - 확인할 대상
     - 명령 예
     - 관찰 범위
   * - 노드 VM
     - virsh list --all
     - 호스트 libvirt가 관리하는 VM
   * - Kubernetes 노드
     - kubectl get nodes
     - 클러스터에 등록된 노드 상태
   * - 서비스 Pod
     - kubectl get pods -n openstack
     - 컨테이너 워크로드 실행 상태
   * - Helm 배포
     - helm list -n openstack --all
     - 설치한 릴리스 상태
   * - OpenStack 컴퓨트
     - openstack compute service list
     - OpenStack 컴퓨트 서비스 상태
   * - 사용자 인스턴스
     - openstack server list
     - 현재 인증 범위에서 조회되는 인스턴스

각 명령에는 해당 시스템의 접속·인증 설정이 필요합니다.
특히 OpenStack CLI는 사용 가능한 엔드포인트와 인증 정보가 있는 환경에서 실행합니다.
검증 결과에는 명령, 실행 위치, 대상, 시각과 성공 기준을 함께 기록합니다.

실습 문서와 연결하기
------------------------------------------------------------

* :doc:`수동구축 </openstack-on-kubernetes/manual/index>` 에서 단계별 실제 작업을 읽습니다.
* :doc:`lab kit 가이드북 </openstack-on-kubernetes/kit/index>` 에서 자동화된 실행 흐름을 읽습니다.

이 역할 표는 0~6단계의 도구 분담을 설명합니다. 수동구축 문서의 추가
Horizon 실습은 웹 UI를 통한 사용자 자원 생성·확인 단계로 이어 읽습니다.
표의 도구 배치만으로 모든 자동화 기능이 구현·검증되었다고 판단하지 않고,
구현 상태와 실행 결과는 코드 및 구축 기록에서 확인합니다.

자료와 참고 문서
------------------------------------------------------------

* 팀 자료 「OpenInfra Lab Kit 구현 도구의 역할」, 1쪽, 0~6단계 역할 표
* `QEMU와 가상화 기반 <https://www.qemu.org/docs/master/system/introduction.html>`_
* `OpenStack-Helm <https://docs.openstack.org/openstack-helm/latest/>`_


현재 구현 코드에서의 연결
------------------------------------------------------------------------------------------

구현 저장소 ``mayura13/openstack_project`` 의 기준 커밋은
``2bc695ebd1eb12059326849c82fe494dcbf48bdb`` 입니다.
PDF의 단계별 역할을 다음 코드와 연결해서 읽을 수 있습니다.

.. list-table:: 역할과 구현 파일
   :header-rows: 1

   * - 단계
     - 구현 위치
     - 역할을 이해할 때 볼 내용
   * - 0
     - ``stage0/``
     - 호스트 검사와 도구 설치, Python 가상환경 분리
   * - 1
     - ``stage1/terraform/``, ``common/generate-inventory.py``
     - Terraform이 생성한 노드 정보를 Ansible 인벤토리로 전달
   * - 2
     - ``stage2/prepare-nodes.yml``
     - swap, 커널 모듈·파라미터, hosts, Netplan 설정
   * - 3
     - ``stage3/``
     - Kubespray 인벤토리 준비와 cluster.yml 실행
   * - 4
     - ``stage4/``
     - kubectl로 라벨 적용, Kubespray로 local-path 구성, Helm 준비
   * - 5
     - ``stage5/deploy.sh``, ``stage5/values/``
     - Horizon을 포함한 12개 릴리스의 차트와 설정 조합
   * - 6. 검증·상태 수집
     - ``stage6/``
     - kubectl port-forward, OpenStack CLI와 curl로 API 검사 및 상태 수집

Helm은 Kubernetes 애플리케이션 배포 도구이고, 이 구현의 단계 전체를 이어 주는
진입점은 Makefile과 Shell입니다. ``make deploy`` 는 0~6단계를 실행합니다.
``make stage-6`` 는 서비스 검증과 상태 수집을 실행하며 사용자 인스턴스 부팅까지
시험하지 않습니다. 검증 결과의 기본 저장 경로는 ``logs/evaluation`` 입니다.

PDF의 4단계 역할을 구체화하면 kubectl은 노드 라벨과 네임스페이스를,
Kubespray는 local-path 구성을, Helm 관련 준비는 차트 배포 도구와 저장소를 담당합니다.
실행법과 알려진 코드 불일치는 :doc:`/openstack-on-kubernetes/kit/index` 와
:doc:`/openstack-on-kubernetes/kit/troubleshooting` 에서 확인합니다.


구현 근거
------------------------------------------------------------------------------------------

* `Makefile <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/Makefile>`_
* `stage2/prepare-nodes.yml <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage2/prepare-nodes.yml>`_
* `stage4/configure-storage.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage4/configure-storage.sh>`_
* `stage6/verify-services.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage6/verify-services.sh>`_