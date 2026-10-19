=============
CSI 기본 개념
=============



CSI란?
------

CSI(Container Storage Interface)는 Kubernetes와 외부 스토리지를
연결하기 위한 표준 인터페이스입니다.

스토리지별 CSI 드라이버는 이 인터페이스를 구현하여
볼륨 생성, 노드 연결, 마운트 등의 작업을 지원합니다.
지원 기능은 드라이버와 스토리지에 따라 다릅니다.



CSI가 필요한 이유
-----------------

Pod의 컨테이너 내부에만 데이터를 저장하면 컨테이너를 다시 만들 때
데이터를 잃을 수 있습니다.

데이터베이스처럼 데이터를 계속 유지해야 하는 애플리케이션은
Pod와 수명주기를 분리한 영구 볼륨을 사용합니다.
CSI 드라이버는 Kubernetes가 외부 스토리지의 볼륨을 사용하도록
연결하는 역할을 합니다.



주요 용어
---------

* 볼륨(Volume):
  애플리케이션이 데이터를 저장하는 공간입니다.
* PV(PersistentVolume):
  Kubernetes에서 사용할 저장공간을 나타내는 리소스입니다.
* PVC(PersistentVolumeClaim):
  애플리케이션이 필요한 저장공간의 크기와 조건을 요청하는
  리소스입니다.
* StorageClass:
  동적으로 볼륨을 생성할 때 사용할 드라이버와
  스토리지 설정을 정의합니다.

예를 들어 사용자는 PVC로 10GiB의 저장공간을 요청하고,
Pod에서 해당 PVC를 참조하여 저장공간을 사용합니다.



OpenStack과의 연결
------------------

OpenStack의 Cinder는 VM에 연결할 블록 스토리지 볼륨을 제공합니다.

OpenStack VM 위에 Kubernetes를 구축한 환경에서는
Cinder CSI 드라이버를 사용하여 Cinder 볼륨을
Pod의 영구 저장공간으로 사용할 수 있습니다.

아래는 동적 볼륨 생성의 개념적인 흐름입니다.

.. code-block:: text

   PVC 생성: 필요한 저장공간 요청
       |
       | StorageClass의 드라이버와 설정 사용
       v
   Cinder CSI 드라이버를 통한 볼륨 생성
       |
       v
   Cinder 볼륨과 이를 나타내는 PV 준비
       |
       v
   PVC와 PV 연결
       |
       v
   Pod가 실행될 노드 VM에 볼륨 연결
       |
       v
   Pod에서 사용할 경로에 마운트

StorageClass 설정에 따라 볼륨 생성은 PVC 생성 직후가 아니라,
해당 PVC를 사용하는 Pod의 배치 시점까지 지연될 수 있습니다.

.. note::

   Cinder CSI를 사용하려면 사용 가능한 Cinder 서비스와
   스토리지 백엔드, 드라이버 및 인증 설정이 필요합니다.
   OpenStack이나 Kubernetes를 설치하는 것만으로
   자동 구성되는 것은 아닙니다.



데이터 유지 시 주의할 점
------------------------------

Pod가 삭제되어도 PVC와 볼륨을 유지하면
새 Pod에서 같은 데이터를 다시 사용할 수 있습니다.

다만 PVC 삭제 시 실제 볼륨이 유지되는지는
PV의 회수 정책(reclaimPolicy)에 따라 달라집니다.

* Delete:
  지원되는 구성에서 PV와 실제 스토리지 볼륨을 삭제합니다.
* Retain:
  실제 데이터를 유지하고 관리자가 후속 처리를 수행합니다.

영구 볼륨을 사용하는 것과 데이터를 백업하는 것은 별개입니다.
중요한 데이터는 별도의 백업 계획이 필요합니다.



CNI와 CSI의 차이
----------------

* CNI(Container Network Interface):
  Pod의 네트워크 연결을 구성합니다.
* CSI(Container Storage Interface):
  외부 스토리지를 연결하여 Pod가 저장공간을 사용하도록 지원합니다.



참고 문서
---------

* `Kubernetes 영구 볼륨
  <https://kubernetes.io/docs/concepts/storage/persistent-volumes/>`_
* `Kubernetes StorageClass
  <https://kubernetes.io/docs/concepts/storage/storage-classes/>`_
* `OpenStack Cinder CSI 드라이버
  <https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/cinder-csi-plugin/using-cinder-csi-plugin.md>`_
