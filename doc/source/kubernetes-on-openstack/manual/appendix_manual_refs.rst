부록 C. 참고 문서
=================

이 문서는 Kubernetes on OpenStack 수동 구축 과정과
관련된 공식 기술 문서 및 프로젝트 자료를 정리합니다.

각 문서는 구성 요소의 개념, 설치 방법, 설정 항목 및
문제 해결 방법을 이해하는 데 활용할 수 있습니다.

OpenStack 및 Kolla-Ansible
--------------------------

* `OpenStack Documentation
  <https://docs.openstack.org/>`_

  OpenStack의 전체 구성과 서비스별 기술 문서입니다.

* `Kolla-Ansible 2026.1 Quick Start
  <https://docs.openstack.org/project-deploy-guide/kolla-ansible/2026.1/quickstart.html>`_

  Kolla-Ansible을 이용한 OpenStack 설치 및 배포
  절차를 확인할 수 있습니다.

* `Kolla-Ansible Source Repository
  <https://opendev.org/openstack/kolla-ansible>`_

  Kolla-Ansible의 소스 코드 및 릴리스 관련 정보를
  확인할 수 있습니다.

이미지 빌드 및 Terraform
------------------------

* `Image Builder
  <https://image-builder.sigs.k8s.io/>`_

  Kubernetes 노드 이미지 생성에 관한 프로젝트
  문서입니다.

* `Image Builder for OpenStack
  <https://image-builder.sigs.k8s.io/capi/providers/openstack>`_

  OpenStack에서 사용할 Kubernetes 노드 이미지의
  빌드 방법을 확인할 수 있습니다.

* `Terraform Documentation
  <https://developer.hashicorp.com/terraform/docs>`_

  Terraform의 설정 문법과 인프라 자원 관리 방법을
  확인할 수 있습니다.

* `Terraform OpenStack Provider
  <https://registry.terraform.io/providers/terraform-provider-openstack/openstack/3.4.0/docs>`_

  OpenStack 네트워크, 이미지, flavor 등의 자원을
  Terraform으로 관리하는 방법을 확인할 수 있습니다.

Kubernetes 및 관리 클러스터
----------------------------

* `Kubernetes Documentation
  <https://kubernetes.io/docs/>`_

  Kubernetes의 구성 요소와 클러스터 운영 방법에
  관한 공식 문서입니다.

* `kind Documentation
  <https://kind.sigs.k8s.io/>`_

  Docker 컨테이너를 이용하여 Kubernetes 클러스터를
  생성하는 방법을 확인할 수 있습니다.

* `kind v0.33.0 Release
  <https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0>`_

  실습에서 사용한 kind 버전의 릴리스 정보입니다.

* `Cluster API Documentation
  <https://cluster-api.sigs.k8s.io/>`_

  Kubernetes 클러스터의 생성과 생명주기 관리에
  관한 공식 문서입니다.

* `Cluster API Releases
  <https://github.com/kubernetes-sigs/cluster-api/releases>`_

  Cluster API 버전별 변경 사항과 릴리스 정보를
  확인할 수 있습니다.

CAPO 및 ORC
------------

* `Cluster API Provider OpenStack
  <https://cluster-api-openstack.sigs.k8s.io/>`_

  Cluster API와 OpenStack 인프라를 연동하는 방법을
  확인할 수 있습니다.

* `CAPO Configuration
  <https://cluster-api-openstack.sigs.k8s.io/clusteropenstack/configuration>`_

  OpenStackCluster 및 관련 인프라 설정 방법을
  확인할 수 있습니다.

* `CAPO v1beta2 API Reference
  <https://cluster-api-openstack.sigs.k8s.io/api/v1beta2/api>`_

  CAPO에서 사용하는 API 리소스와 설정 항목에 관한
  참고 문서입니다.

* `CAPO Releases
  <https://github.com/kubernetes-sigs/cluster-api-provider-openstack/releases>`_

  CAPO 버전별 릴리스 정보를 확인할 수 있습니다.

* `OpenStack Resource Controller
  <https://k-orc.pages.dev/>`_

  Kubernetes 리소스를 이용한 OpenStack 자원 관리에
  관한 프로젝트 문서입니다.

* `ORC Installation
  <https://k-orc.pages.dev/installation>`_

  ORC 설치 방법을 확인할 수 있습니다.

Calico 및 OCCM
---------------

* `Calico Documentation
  <https://docs.tigera.io/calico/latest/>`_

  Kubernetes 파드 네트워크 및 네트워크 정책에 관한
  공식 문서입니다.

* `Calico Requirements
  <https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements>`_

  Calico 설치에 필요한 Kubernetes 및 시스템
  요구사항을 확인할 수 있습니다.

* `Calico Releases
  <https://github.com/projectcalico/calico/releases>`_

  Calico 버전별 변경 사항과 릴리스 정보를
  확인할 수 있습니다.

* `CAPO External Cloud Provider
  <https://cluster-api-openstack.sigs.k8s.io/topics/external-cloud-provider>`_

  Kubernetes와 OpenStack의 클라우드 연동에 필요한
  OCCM 구성 방법을 확인할 수 있습니다.

* `Cloud Provider OpenStack
  <https://github.com/kubernetes/cloud-provider-openstack>`_

  OpenStack Cloud Controller Manager의 소스 코드와
  관련 매니페스트를 확인할 수 있습니다.

* `Cloud Provider OpenStack Releases
  <https://github.com/kubernetes/cloud-provider-openstack/releases>`_

  Kubernetes 버전에 대응하는 OCCM의 릴리스 정보를
  확인할 수 있습니다.

참고 시 주의사항
----------------

공식 문서는 프로젝트의 버전과 릴리스에 따라 내용이
변경될 수 있습니다.

최신 버전의 문서를 참고하는 경우 이 가이드에서 사용한
버전과 설정 항목에 차이가 있는지 확인해야 합니다.

이 가이드에서 사용한 구체적인 도구 버전은
:doc:`appendix_versions` 문서를 참고합니다.

실제 구축 과정에서 확인한 동작과 공식적으로 지원되는
구성은 구분하여 해석해야 합니다.

공식 호환성이 확인되지 않은 구성은
:doc:`appendix_diagnostics` 문서에 별도로 정리했습니다.
