실습 환경과 구축 범위
========================

호스트는 Ubuntu 24.04.1을 설치한 서버입니다. CPU는 Intel Xeon Gold 6262(2소켓, 96스레드),
메모리는 125 GiB, SSD는 약 465.8 GB였습니다. 호스트에는 ``lab`` 계정으로, VM에는 ``kit`` 계정으로 접속했습니다.

.. list-table:: 노드별 역할과 할당량
   :header-rows: 1

   * - 노드
     - 역할
     - IP
     - vCPU / 메모리 / 디스크
   * - cp
     - Kubernetes 컨트롤 플레인과 etcd
     - 192.168.100.10
     - 4 / 16 GiB / 60 GB
   * - ctrl-worker
     - OpenStack 제어 서비스
     - 192.168.100.11
     - 16 / 32 GiB / 120 GB
   * - compute-1
     - OpenStack 컴퓨트 서비스
     - 192.168.100.21
     - 10 / 32 GiB / 80 GB
   * - compute-2
     - OpenStack 컴퓨트 서비스
     - 192.168.100.22
     - 10 / 32 GiB / 80 GB

Terraform과 libvirt로 VM을 만들고, Ansible로 노드 설정을 맞췄습니다.
Kubespray로 Kubernetes를 설치한 뒤 Helm으로 OpenStack 서비스를 배포했습니다.
2026년 11월 1일 배포를 마쳤고, 11월 2일에 서비스 상태와 API 응답을 확인했습니다.

이번 기록의 범위는 단일 호스트에서 수행한 수동 구축입니다. 사용자 인스턴스 부팅, Floating IP,
호스트 장애 복구, 새 서버에서의 반복 구축은 별도 검증 항목입니다. ``make up`` 등 키트 명령도 향후 구현 범위입니다.