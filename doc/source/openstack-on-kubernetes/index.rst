=======================
OpenStack on Kubernetes
=======================

OpenStack 의 각 서비스(Keystone, Glance, Neutron, Nova, Placement 등)를
컨테이너로 패키징해 Kubernetes 위에서 운영하는 방식입니다.

이 장은 같은 구조를 두 가지 방식으로 다룹니다. 두 문서 모두 베어메탈 서버 한 대에서
가상 노드 4대를 만들고, 그 위에 Kubernetes 와 OpenStack 을 구축하는 환경을 대상으로
합니다.

.. list-table::
   :header-rows: 1
   :widths: 20 40 40

   * - 문서
     - 내용
     - 이런 때 읽으세요
   * - :doc:`수동구축 <manual/index>`
     - 명령을 직접 입력하며 구축한 과정과 시행착오의 기록
     - 구축이 어떤 단계로 이루어지는지, 어디서 막히는지 알고 싶을 때
   * - :doc:`lab kit 가이드북 <kit/index>`
     - 자동화 키트(``make`` 명령)로 같은 환경을 재현하는 방법
     - 직접 구축해 보거나 실습 환경을 반복해서 만들고 싶을 때

