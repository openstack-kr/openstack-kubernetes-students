0단계. 실습 환경 준비 및 도구 설치
===================================

이 단계에서는 OpenStack 구축에 필요한 시스템 패키지,
Python 가상환경, Ansible 및 Kolla-Ansible을 설치합니다.

Kolla-Ansible은 Ansible을 이용하여 OpenStack 서비스를
컨테이너 형태로 배포하고 관리하는 도구입니다.

사전 환경 확인
--------------

원격 서버에 접속한 뒤 운영체제와 시스템 자원을 확인합니다.

.. code-block:: bash

   cat /etc/os-release
   lscpu
   free -h
   df -h
   ip -br addr
   ls -l /dev/kvm

인터넷 연결과 sudo 권한도 사용할 수 있어야 합니다.

시스템 패키지 설치
------------------

패키지 목록을 갱신합니다.

.. code-block:: bash

   sudo apt update

Python 가상환경과 라이브러리 설치에 필요한 패키지를
설치합니다.

.. code-block:: bash

   sudo apt install -y git python3-dev python3-venv \
       libffi-dev gcc libssl-dev libdbus-glib-1-dev

Python 가상환경 생성
--------------------

Python 가상환경은 프로젝트에 필요한 Python 패키지를
시스템 환경과 분리하여 관리하기 위한 공간입니다.

.. code-block:: bash

   python3 -m venv ~/kolla-venv
   source ~/kolla-venv/bin/activate

가상환경이 활성화되면 터미널에 ``(kolla-venv)`` 가 표시됩니다.

.. code-block:: bash

   pip install -U pip

.. note::

   새로운 터미널을 열거나 서버에 다시 접속하면 가상환경을
   다시 활성화해야 합니다.

Ansible 설치
------------

Kolla-Ansible이 사용하는 Ansible Core를 설치합니다.

.. code-block:: bash

   pip install 'ansible-core>=2.19,<2.20.99'

설치된 버전을 확인합니다.

.. code-block:: bash

   ansible --version

Kolla-Ansible 설치
-------------------------

구축 환경의 재현성을 확보하기 위해 실습에서 사용한
22.2.0 버전으로 설치합니다.

.. code-block:: bash

   pip install \
       'git+https://opendev.org/openstack/kolla-ansible@22.2.0'

설치 결과를 확인합니다.

.. code-block:: bash

   pip show kolla-ansible

Version 항목이 22.2.0인지 확인합니다.

설정 파일 준비
--------------

Kolla-Ansible의 설정 파일을 저장할 디렉터리를 생성합니다.

.. code-block:: bash

   sudo mkdir -p /etc/kolla
   sudo chown "$USER:$USER" /etc/kolla

기본 설정 파일을 복사합니다.

.. code-block:: bash

   cp -r ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/* \
       /etc/kolla/

단일 서버 구축에 사용하는 all-in-one 인벤토리를 복사합니다.

.. code-block:: bash

   cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/all-in-one \
       ~/

인벤토리는 Ansible이 작업을 수행할 서버와 서버별 역할을
정의하는 파일입니다.

Ansible 의존성 설치
-------------------

Kolla-Ansible에서 사용하는 Ansible 컬렉션과 의존성을
설치합니다.

.. code-block:: bash

   kolla-ansible install-deps

서비스 비밀번호 생성
--------------------

OpenStack 서비스에서 사용할 비밀번호를 생성합니다.

.. code-block:: bash

   kolla-genpwd
   chmod 600 /etc/kolla/passwords.yml

.. warning::

   passwords.yml에는 OpenStack 서비스의 인증 정보가
   포함됩니다. 파일 내용을 출력하거나 공개하지 않습니다.

설치 결과 확인
--------------

.. code-block:: bash

   ansible --version
   pip show kolla-ansible
   ls -l /etc/kolla/passwords.yml
   ls -l /etc/kolla/globals.yml
   ls -l ~/all-in-one

완료 기준
---------

* Python 가상환경 활성화 가능
* Ansible Core 2.19 또는 2.20 설치
* Kolla-Ansible 22.2.0 설치
* globals.yml 파일 존재
* passwords.yml 파일 존재 및 권한 600
* all-in-one 인벤토리 파일 존재

문제 해결
---------

passwords file missing 오류
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

kolla-genpwd 실행 시 비밀번호 파일을 찾을 수 없다는
오류가 발생할 수 있습니다.

이 경우 /etc/kolla 디렉터리와 기본 설정 파일이 정상적으로
복사되었는지 확인한 뒤 다시 실행합니다.

비밀번호 파일 권한 경고
~~~~~~~~~~~~~~~~~~~~~~~~

비밀번호 파일에 다른 사용자의 접근 권한이 있는 경우
다음 명령어로 권한을 제한합니다.

.. code-block:: bash

   chmod 600 /etc/kolla/passwords.yml

참고 문서
---------

* `Kolla-Ansible Quick Start
  <https://docs.openstack.org/project-deploy-guide/kolla-ansible/2026.1/quickstart.html>`_
