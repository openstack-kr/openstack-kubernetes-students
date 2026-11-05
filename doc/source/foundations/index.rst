=========
기초 개념
=========

이 장은 서버 가상화에서 시작해 OpenStack과 Kubernetes의 역할,
두 시스템을 연결하는 방법과 실습 도구의 역할을 설명합니다.
처음 읽는 경우 아래 순서대로 읽으면 수동구축과 lab kit 가이드북의 용어를
이해하는 데 도움이 됩니다.

OpenStack에서는 인스턴스·네트워크·볼륨 같은 클라우드 자원을 다루고,
Kubernetes에서는 Pod와 Service 같은 컨테이너 실행 자원을 다룹니다.
이 실습은 Kubernetes 위에서 OpenStack 서비스를 운영하는 구조를 학습합니다.

.. toctree::
   :maxdepth: 1

   vm-vs-container
   openstack-fundamentals
   kubernetes-fundamentals
   helm
   bridging-concepts
   kubernetes-csi
   lab-kit-tools

기초 개념을 읽은 뒤 :doc:`수동구축 </openstack-on-kubernetes/manual/index>` 또는
:doc:`lab kit 가이드북 </openstack-on-kubernetes/kit/index>` 으로 이동합니다.
