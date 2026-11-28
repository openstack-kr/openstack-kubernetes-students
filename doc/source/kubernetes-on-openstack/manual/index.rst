수동 구축
=========

이 가이드는 Kubernetes on OpenStack 환경을 처음 구축하는
사용자가 전체 구성과 각 도구의 역할을 이해하고, 단계별로
실습을 진행할 수 있도록 작성되었습니다.

단순히 명령어를 실행하는 것뿐만 아니라 각 명령어의 목적,
설정 방법, 정상 동작 확인 방법 및 실제 구축 과정에서 발생한
문제와 해결 방법을 함께 설명합니다.

구축 목표
---------

* Kolla-Ansible을 이용한 OpenStack 구축
* Kubernetes 노드 이미지 생성
* Terraform을 이용한 OpenStack 공용 자원 구성
* kind 기반 관리 클러스터 구축
* Cluster API와 CAPO를 이용한 Kubernetes 클러스터 생성
* Calico와 OCCM 설치 및 서비스 동작 검증
* 클러스터 삭제 후 OpenStack 자원 정리 검증

전체 구축 흐름
--------------

.. code-block:: text

   0단계: 환경 준비 및 도구 설치
       |
       v
   1단계: Kolla-Ansible로 OpenStack 구축
       |
       v
   2단계: 노드 이미지 생성 및 Terraform 자원 구성
       |
       v
   3단계: kind 관리 클러스터와 Cluster API 설치
       |
       v
   4단계: CAPO로 Kubernetes 클러스터 생성
       |
       v
   5단계: Calico 및 OCCM 설치와 동작 검증
       |
       v
   6단계: 클러스터 삭제 및 자원 정리 검증

가이드 읽는 방법
----------------

각 단계는 이전 단계가 정상적으로 완료되었다는 것을
전제로 합니다.

처음 구축하는 경우 0단계부터 순서대로 진행하며,
각 단계의 검증 결과를 확인한 뒤 다음 단계로 이동합니다.

구축 과정에서 오류가 발생한 경우 문제 해결 문서를
참고하여 원인을 확인합니다.

.. warning::

   이 가이드는 전용 실습 서버를 기준으로 작성되었습니다.

   기존 서비스가 운영 중인 서버에서는 네트워크 설정 변경,
   서비스 중지 및 자원 삭제 명령을 그대로 실행하지 않습니다.

목차
----

.. toctree::
   :maxdepth: 2

   overview
   ch0_prerequisites
   ch1_openstack
   ch2_image_terraform
   ch3_management_cluster
   ch4_capo
   ch5_calico_occm
   ch6_cleanup
   ch7_troubleshooting
   appendix_versions
   appendix_diagnostics
   appendix_manual_refs
