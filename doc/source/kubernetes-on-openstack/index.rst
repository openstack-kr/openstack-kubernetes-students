Kubernetes on OpenStack
=======================

Kubernetes on OpenStack(KoO)은 OpenStack이 제공하는 가상 머신
인프라 위에 Kubernetes 클러스터를 구축하고 운영하는 방식입니다.

OpenStack은 가상 머신, 네트워크, 이미지 등의 인프라 자원을
제공하며, Kubernetes는 이러한 가상 머신 위에서 컨테이너
애플리케이션을 배포하고 관리합니다.

이 문서에서는 단일 베어메탈 서버에 OpenStack을 구축한 뒤,
Cluster API와 CAPO를 이용하여 Kubernetes 클러스터를
생성하는 과정을 설명합니다.

.. toctree::
   :maxdepth: 2

   manual/index
