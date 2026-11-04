.. _troubleshooting:

=======================
문제 해결과 구현 확인 사항
=======================
.. warning::

   이 장의 불일치는 기준 커밋을 정적으로 대조한 결과입니다.
    문서를 바꾸어도 구현 코드의 오류가 자동으로 수정되는 것은 아닙니다.

실행 전 수정·확인할 두 항목
------------------------------------------------------------------------------------------

**1. libvirt 풀 이름**

``stage1/terraform/main.tf`` 는 실제 풀을 ``openinfra-lab`` 으로 생성하지만
``stage1/postcheck.sh`` 는 ``openinfra`` 를 조회합니다.
``scripts/reset-lab.sh`` 의 수동 정리 분기에도 ``POOL="openinfra"`` 가 남아 있습니다.
생성·점검·정리에서 동일한 실제 이름을 사용하도록 맞추어야 합니다.
과거에 만든 ``openinfra`` 풀이 있으면 잘못된 대상 검사나 정리로 이어질 수 있으므로
이름만 보고 삭제하지 말고 소유 자원과 경로를 확인합니다.

**2. 5단계 values 개수**

``stage5/preflight.sh`` 의 기대값은 11개, 실제 파일과 배포 대상은 12개입니다.
Horizon 추가가 사전 점검에 반영되지 않은 상태입니다.
배포에 필요한 파일 목록을 기준으로 검사하도록 구현을 맞추고 재점검합니다.

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
* 5단계는 Pod 준비 완료를 기다리지 않아 사후 점검 시점에 따라 실패할 수 있습니다.
  재점검 전 실제 Pod 이벤트를 확인합니다.

초기화 기능
------------------------------------------------------------------------------------------

``make reset-dry-run`` 으로 정리 대상을 미리 확인할 수 있습니다.
``make reset`` 은 실제 VM과 디스크 등을 삭제하는 명령이며 데이터가 사라집니다.
Terraform 상태가 있으면 destroy를 사용하고, 없으면 정해진 이름의 libvirt 자원을
찾는 분기로 들어갑니다. 위 풀 이름 불일치를 해결하고 대상과 백업을 확인하기 전에는
실제 초기화를 실행하지 않습니다. 초기화는 실패 로그 수집을 대신하지 않습니다.


구현 근거
------------------------------------------------------------------------------------------

* `stage1/terraform/main.tf <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage1/terraform/main.tf>`_
* `stage1/postcheck.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage1/postcheck.sh>`_
* `stage5/preflight.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/stage5/preflight.sh>`_
* `scripts/reset-lab.sh <https://github.com/mayura13/openstack_project/tree/de7f93327e089368c8ad8a63436075f32a3ae17b/scripts/reset-lab.sh>`_