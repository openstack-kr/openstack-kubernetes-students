.. _troubleshooting:

=======================
문제 해결과 구현 확인 사항
=======================
이 장의 불일치는 기준 커밋을 정적으로 대조한 결과입니다.
문서를 바꾸어도 구현 코드의 오류가 자동으로 수정되는 것은 아닙니다.

초기화 전에 확인할 저장소 풀 이름
------------------------------------------------------------------------------------------

``stage1/terraform/main.tf`` 는 풀을 ``openinfra-lab`` 으로 생성하고,
``stage1/postcheck.sh`` 의 실제 조회 명령도 같은 이름으로 수정되었습니다.
그러나 ``scripts/reset-lab.sh`` 의 수동 정리 분기에는 ``POOL="openinfra"`` 가 남아 있습니다.
Terraform 상태가 없어 수동 정리 분기로 들어가면 잘못된 이름의 풀을 대상으로 삼을 수 있습니다.

.. warning::

   초기화를 실행하기 전에 수동 정리 분기의 풀 이름을 실제 생성 대상과 맞추고,
   풀 경로와 소유 자원을 확인해야 합니다. 과거에 만든 ``openinfra`` 풀이 있다면
   별개 자원일 수 있습니다. 이름만 보고 삭제하지 마세요.

해결된 검사와 남은 안내 문구
------------------------------------------------------------------------------------------

5단계 사전 점검의 파일 개수 비교는 **12개** 로 수정되었습니다.
이전의 11개 기대값 때문에 배포가 차단되던 불일치는 해결됐습니다.
다만 성공 메시지는 아직 11개라고 표시하므로 문구 정리가 필요합니다.
1단계 풀 검사 메시지에도 이전 이름 ``openinfra`` 가 남아 있습니다.
이 두 메시지와 실제 검사 조건을 구분해서 읽습니다.

6단계 파일은 ``evaluation/`` 에서 ``stage6/`` 로 이동했고 Makefile에도 연결되었습니다.
스크립트 주석에 남은 “Makefile에는 연결되어 있지 않습니다”는 이전 설명입니다.
현재 실행 흐름은 Makefile과 :doc:`verification` 을 기준으로 확인합니다.

진단 명령
------------------------------------------------------------------------------------------

.. code-block:: bash

   virsh pool-list --all
   virsh pool-info openinfra-lab
   find stage5/values -maxdepth 1 -type f -name 'values-*.yaml' | sort
   kubectl get nodes -o wide
   kubectl get pods -n openstack -o wide
   kubectl get events -n openstack --sort-by=.metadata.creationTimestamp
   helm list -n openstack --all

실패한 Pod는 실제 이름으로 ``kubectl describe pod`` 와 ``kubectl logs`` 를 실행하여
이벤트·컨테이너 로그를 확인합니다. 발생 시각, 명령, 대상 노드, 버전, 오류와
조치 후 결과를 함께 기록합니다. 공유 로그에서는 인증 정보를 제거합니다.

재실행 시 주의할 동작
------------------------------------------------------------------------------------------

* 0단계 사후 점검은 잔여 VM을, 1단계 사전 점검은 같은 이름의 기존 VM을 검사합니다.
  실패 뒤 ``make deploy`` 를 무조건 다시 실행하는 복구 방식은 지원되지 않습니다.
* 3단계 준비는 생성한 Kubespray 인벤토리 폴더를 다시 만듭니다.
* 4단계 준비는 호스트 kubeconfig와 OpenStack-Helm 소스 폴더에 영향을 줍니다.
* 5단계는 사후 점검을 반복하는 대기 스크립트를 사용합니다. 제한 시간 이후에도
  실패한다면 기다리기만 하지 말고 Pod 이벤트와 컨테이너 로그를 확인합니다.
* 6단계의 기본 출력은 ``logs/evaluation`` 아래에 저장됩니다.
  반복 실행 전에 회차별 결과를 보관합니다.

초기화 기능
------------------------------------------------------------------------------------------

``make reset-dry-run`` 으로 정리 대상을 미리 확인할 수 있습니다.
``make reset`` 은 실제 VM과 디스크 등을 삭제하는 명령이며 데이터가 사라집니다.
Terraform 상태가 있으면 destroy를 사용하고, 없으면 정해진 이름의 libvirt 자원을
찾는 분기로 들어갑니다. 위 풀 이름 불일치를 해결하고 대상과 백업을 확인하기 전에는
실제 초기화를 실행하지 않습니다. 초기화는 실패 로그 수집을 대신하지 않습니다.


구현 근거
------------------------------------------------------------------------------------------

* `stage1/terraform/main.tf <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage1/terraform/main.tf>`_
* `stage1/postcheck.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage1/postcheck.sh>`_
* `stage5/preflight.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/stage5/preflight.sh>`_
* `scripts/reset-lab.sh <https://github.com/mayura13/openstack_project/tree/2bc695ebd1eb12059326849c82fe494dcbf48bdb/scripts/reset-lab.sh>`_