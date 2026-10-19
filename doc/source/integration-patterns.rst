================
통합 패턴
================

OpenStack과 Kubernetes를 결합하는 두 가지 방향을 다룹니다.

* Kubernetes on OpenStack:
  OpenStack이 제공하는 VM 위에 Kubernetes를 구축합니다.
* OpenStack on Kubernetes:
  Kubernetes 위에 OpenStack 서비스를 배포합니다.

구성 예시
---------

아래는 베어메탈 서버를 기반으로 두 환경을 독립적으로 구축하는 예시입니다.

.. code-block:: text

   Kubernetes on OpenStack
   -----------------------

   베어메탈 서버
       |
       | Kolla-Ansible
       v
   OpenStack
       |
       | Terraform: 기반 네트워크 등 준비
       | Cluster API + CAPO: 노드 VM 생성·관리
       v
   VM 위의 Kubernetes
       |
       v
   테스트 애플리케이션


   OpenStack on Kubernetes
   -----------------------

   베어메탈 서버
       |
       | Kubernetes 구축
       v
   Kubernetes
       |
       | OpenStack-Helm
       v
   OpenStack
       |
       v
   테스트용 VM

.. note::

   Terraform과 CAPO의 자원 관리 범위는 중복되지 않도록 정합니다.
   Cluster API와 CAPO를 실행할 관리용 Kubernetes는 별도로 필요합니다.

상세 가이드
-----------

.. toctree::
   :maxdepth: 2

   openstack-on-kubernetes/index
   kubernetes-on-openstack/index
