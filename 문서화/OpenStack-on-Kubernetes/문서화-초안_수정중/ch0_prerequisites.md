# 0단계. 서버 확인과 도구 설치

## 이 단계가 하는 일

- 빌린 서버가 이 실습에 적합한지 읽기만 하는 명령으로 확인합니다.
- 작업용 계정(`lab`)과 기록 환경을 준비합니다.
- 이후 단계에서 쓸 도구(Terraform, kubectl, Helm, Ansible, Kubespray, openstack CLI)를 정해진 버전으로 설치합니다.

이 단계에서는 VM이나 Kubernetes를 만들지 않습니다. 서버에 도구를 설치하고 점검만 합니다.

> [!NOTE]
> 이 가이드는 현재 **수동 구축**(공식 문서 절차를 직접 따라 하는 방식)의 기록입니다.
> 명령을 한 번에 실행해 주는 자동화 키트는 수동 구축을 마친 뒤에 만들며,
> 그때 각 장의 "키트로 실행하기"를 채웁니다.

## 선행 조건

- **베어메탈 서버** 1대. 서버 안에 VM을 여러 대 만들어야 하므로, 서버 자체가 가상 서버(인스턴스)이면 이 실습을 따라 할 수 없을 수 있습니다.
- 서버에 SSH로 접속할 수 있고, 관리자(root) 권한을 쓸 수 있을 것.
- 서버에서 인터넷(HTTPS)으로 패키지와 이미지를 받을 수 있을 것.

이 가이드를 작성한 서버의 사양은 다음과 같습니다. 이보다 작으면 이후 단계의 VM 사양을 줄여야 합니다.

| 항목 | 값 |
|---|---|
| CPU | Intel Xeon Gold 6262, 2소켓, 96스레드 |
| 메모리 | 125GiB |
| 디스크 | SSD 약 465GB (여유 약 452GB) |
| OS | Ubuntu 24.04.1 LTS (Noble), 커널 6.8 |

## 키트로 실행하기

> [!NOTE]
> **TODO:** 자동화 키트 완성 후 `make preflight` / `make install` 사용법을 채울 것.

## 단계별로 따라 하기

### 1. 서버 환경 확인 (읽기 전용)

아래 명령은 서버에 아무것도 바꾸지 않습니다. 결과가 기대와 다르면 **다음으로 넘어가지 말고** 원인을 먼저 확인하세요.

```bash
# 베어메탈인지, VM을 만들 수 있는지 (가장 중요)
systemd-detect-virt            # none 이면 베어메탈
ls -l /dev/kvm                 # 파일이 있어야 함
grep -c vmx /proc/cpuinfo      # 0보다 커야 함

# 자원과 OS
nproc
free -h
df -h
lsblk
cat /etc/os-release | head -4

# 외부 접속 (200, 301, 307, 401은 접속됨, 000은 막힘)
for u in https://registry.k8s.io https://quay.io https://github.com \
         https://registry-1.docker.io/v2/ https://opendev.org \
         https://registry.terraform.io; do
  printf "%s -> " "$u"; curl -s -o /dev/null -m 10 -w "%{http_code}\n" "$u"
done
```

| 확인 항목 | 기대 결과 |
|---|---|
| `systemd-detect-virt` | `none` (베어메탈) |
| `/dev/kvm` | 파일이 있음 |
| `grep -c vmx /proc/cpuinfo` | 0보다 큰 수 (CPU가 가상화를 지원) |
| OS | Ubuntu 24.04 (Noble) |
| 외부 접속 | 6곳 모두 000이 아님 (`registry-1.docker.io` 의 401은 정상) |

> [!NOTE]
> `grep -c vmx` 는 CPU 스레드 수보다 큰 값(예: 스레드 96개인데 192)이 나올 수 있습니다.
> `/proc/cpuinfo` 에 `flags` 줄과 `vmx flags` 줄이 모두 있어 두 번 세어지기 때문이며 오류가 아닙니다.

### 2. 작업 계정과 기록 환경 만들기

root로 계속 작업하면 나중에 입문자가 따라 할 때 환경이 달라집니다.
또한 "libvirt 그룹에 계정을 추가하고 다시 로그인한다"는 절차를 검증하려면 일반 계정이 필요합니다.
그래서 `lab` 이라는 일반 계정을 만들어 사용합니다. (root 터미널에서 실행)

```bash
adduser --disabled-password --gecos "" lab
usermod -aG sudo,kvm lab
echo 'lab ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-lab
chmod 440 /etc/sudoers.d/90-lab && visudo -cf /etc/sudoers.d/90-lab
mkdir -p /home/lab/.ssh
cp ~/.ssh/authorized_keys /home/lab/.ssh/
chown -R lab:lab /home/lab/.ssh
chmod 700 /home/lab/.ssh && chmod 600 /home/lab/.ssh/authorized_keys
apt-get install -y tmux
```

- **비밀번호 없는 sudo**: 구축에는 수십 분이 걸리는데, 중간에 sudo 인증이 만료되면 작업이 실패합니다. 실습용 서버라서 감수하는 설정이며, 로그인은 SSH 키로만 합니다.
- **tmux**: SSH 연결이 끊겨도 서버 안의 작업이 계속 돌게 해 주는 도구입니다. (아래 설명 참고)

새 터미널에서 `lab` 으로 접속해 확인합니다.

```bash
ssh lab@<서버 주소>
id; sudo -n true && echo "sudo OK"; ls -l /dev/kvm
```

`id` 에 `sudo`, `kvm` 그룹이 보이고 `sudo OK` 가 나오면 됩니다.

**tmux 사용법 (이후 모든 단계에서 사용)**

```bash
tmux new -s kit        # 처음 시작: 이름이 kit 인 세션을 만듦
# 빠져나오기: Ctrl+b 를 누르고 손을 뗀 뒤 d
tmux attach -t kit     # 다시 들어가기
```

**명령 기록 설정 (한 번만)**

"몇 개의 명령을 직접 입력했는가"가 자동화 효과를 보여 주는 근거라서, 모든 명령을 시각과 함께 남깁니다.

```bash
echo 'export HISTTIMEFORMAT="%F %T "; export HISTSIZE=100000; shopt -s histappend; PROMPT_COMMAND="history -a"' >> ~/.bashrc
source ~/.bashrc
```

명령을 입력하기 전에 단계 표식을 한 줄 남깁니다. 표식도 히스토리에 남아 나중에 구분하는 기준이 됩니다.

| 표식 | 뜻 |
|---|---|
| `# STAGE n` | n단계 작업을 시작함 |
| `# MANUAL n` | 이후 명령은 수동 명령 집계 대상 (설치, 실행 명령) |
| `# NOTE n` | 확인용 명령 (집계에서 제외) |

### 3. 시간 동기화 확인

서버 시계가 실제 시각과 다르면 나중에 인증서 유효 시간 때문에 Kubernetes가 실패할 수 있어서,
설치 전에 시계가 맞는지 확인합니다.

```bash
timedatectl | grep -E "synchronized|NTP"
chronyc tracking
chronyc sources
```

기대 결과는 `System clock synchronized: yes` 이고, `chronyc sources` 의 `Reach` 값이 0이 아닌 것입니다.
`Reach` 가 0이면 시간 서버의 응답이 서버에 오지 않는 상태입니다.
원인과 해결은 [문제 해결](ch7_troubleshooting.md) 의 "시계가 맞지 않음"을 참고하세요.

### 4. 도구 설치

앞으로 쓸 도구를 설치합니다. 버전은 결과가 매번 같도록 정해 둔 값입니다. ([부록 A. 버전 표](appendix_versions.md))
`lab` 계정에서 실행합니다.

```bash
# 기본 패키지와 libvirt/KVM (VM을 만들 때 쓰는 가상화 도구)
sudo apt-get update
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients \
  virtinst bridge-utils genisoimage git make curl unzip jq \
  python3-venv python3-pip
sudo usermod -aG libvirt lab
# 그룹은 다시 로그인해야 적용됩니다 (tmux를 나가서 접속을 끊었다가 다시 접속)

# Terraform 1.15.9 (VM을 코드로 만드는 도구)
cd /tmp
curl -fsSLO https://releases.hashicorp.com/terraform/1.15.9/terraform_1.15.9_linux_amd64.zip
unzip terraform_1.15.9_linux_amd64.zip
sudo install terraform /usr/local/bin/terraform

# kubectl v1.35.4 (Kubernetes에 명령을 내리는 도구)
curl -fsSLO https://dl.k8s.io/release/v1.35.4/bin/linux/amd64/kubectl
sudo install -m 0755 kubectl /usr/local/bin/kubectl

# Helm v3.18.4 (Kubernetes 앱 설치 도구)
curl -fsSLO https://get.helm.sh/helm-v3.18.4-linux-amd64.tar.gz
tar -xzf helm-v3.18.4-linux-amd64.tar.gz
sudo install linux-amd64/helm /usr/local/bin/helm

# Kubespray v2.31.0 와 Ansible (가상환경 안에 설치)
cd ~
git clone --branch v2.31.0 --depth 1 https://github.com/kubernetes-sigs/kubespray.git
python3 -m venv ~/venv-kubespray
source ~/venv-kubespray/bin/activate
pip install -U pip
pip install -r ~/kubespray/requirements.txt
deactivate

# openstack CLI (가상환경 안에 설치)
python3 -m venv ~/venv-openstack
source ~/venv-openstack/bin/activate
pip install python-openstackclient
deactivate
```

> [!NOTE]
> **가상환경(venv)** 은 파이썬 도구를 서버의 다른 프로그램과 섞이지 않게 따로 설치하는 폴더입니다.
> `source ~/venv-kubespray/bin/activate` 를 하면 프롬프트 앞에 `(venv-kubespray)` 가 붙고,
> 이후 Ansible 명령을 쓸 수 있습니다. **터미널을 새로 열 때마다** 다시 `activate` 해야 합니다.

### 5. 설치 후 점검

```bash
terraform version; kubectl version --client; helm version --short
source ~/venv-kubespray/bin/activate; ansible --version | head -1; deactivate
source ~/venv-openstack/bin/activate; openstack --version; deactivate
git -C ~/kubespray describe --tags
groups                              # libvirt, kvm 이 보여야 함
virsh list --all                    # sudo 없이 동작해야 함 (VM 목록은 비어 있음)
```

| 점검 항목 | 기대 결과 |
|---|---|
| terraform / kubectl / helm 버전 | 1.15.9 / v1.35.4 / v3.18.4 |
| ansible-core, openstack CLI | 2.18.x / 10.5.0 |
| Kubespray | v2.31.0 |
| 작업 계정이 root가 아님 | `lab` |
| `libvirt`, `kvm` 그룹, `/dev/kvm` | 있음 |
| sudo 없이 `virsh` 동작 | 동작함 |
| 잔여 VM 없음 | 목록이 비어 있음 |
| 시간 동기화 | `yes` |

## 기대 결과

위 점검이 모두 통과하면 0단계가 끝난 것입니다. 이 가이드를 작성한 환경에서는 점검 13항목이 모두 통과했고,
시계 문제 해결 시간을 빼면 설치와 점검에 약 30분이 걸렸습니다.

> [!NOTE]
> **TODO:** 점검 통과 시 출력 예시를 실제 출력으로 붙여 넣기.

## 확인 방법

- `history | grep -E "# (STAGE|MANUAL) 0"` 으로 표식이 남았는지 봅니다.
- 환경 확인 출력은 `~/logs/` 아래 파일로 저장해 두면 나중에 근거 자료가 됩니다.

## 이 단계에서 겪은 오류와 주의사항

> [!WARNING]
> **서버 시계가 실제보다 6분 이상 늦어질 수 있습니다.**
> 서버 업체의 방화벽이 "서버에서 밖으로 나가는" 통신을 포트별로 제한하는 경우,
> 시간 서버로 가는 **UDP 123번** 이 막혀 있으면 시계 보정이 안 됩니다.
> (이 가이드의 서버는 실제보다 366.4초 늦었습니다.)
> 방화벽의 "나가는 목적지 포트"에 `ntp / udp / 123` 을 추가한 뒤
> `sudo chronyc makestep` 으로 시계를 한 번에 맞췄습니다.
> 이 키트는 **UDP 123이 허용된 환경** 을 전제로 합니다.

> [!WARNING]
> **서버에서 밖으로 나가는 SSH(22번)가 막혀 있을 수 있습니다.**
> 그러면 `git clone git@github.com:...` 형태의 주소가 멈춥니다.
> 이 가이드는 모두 `https://` 주소를 사용합니다.

> [!NOTE]
> **명령을 어디서 실행하는지 구분하세요.**
> `scp` 로 서버의 파일을 내 컴퓨터로 가져올 때는 **내 컴퓨터의 터미널** 에서 실행합니다.
> 서버 안에서 실행하면 서버가 자기 자신에게 복사하려고 해서 지문 확인 질문에서 멈춥니다.
> Mac의 zsh에서는 `*` 가 들어간 주소를 작은따옴표로 감싸야 하고(`'lab@서버:~/파일-*.txt'`),
> `# NOTE ...` 같은 표식 줄은 주석으로 처리되지 않아 `command not found` 가 납니다.
> 표식은 서버(bash)에서만 입력하세요.

> [!NOTE]
> **SSH 접속이 갑자기 안 될 수 있습니다.**
> 이 가이드를 쓰는 동안 약 1시간 동안 서버에 SSH가 연결되지 않은 적이 있었습니다.
> 서버가 재부팅된 것은 아니었고(가동 시간이 이어짐) 원인은 확인하지 못했습니다.
> `tmux` 안에서 작업했다면 서버 안의 작업은 그대로 유지됩니다.
> 접속이 안 되면 다른 네트워크(휴대폰 핫스팟 등)로 바꿔 보고,
> `nc -vz -w 5 <서버 주소> 22` 로 22번 포트가 열려 있는지 확인하세요.

> [!NOTE]
> **여러 명이 같은 `lab` 계정을 쓰면** 명령 기록(`.bash_history`)이 한 파일에 섞이고,
> Terraform 같은 명령을 동시에 실행하면 서로 충돌합니다.
> 팀으로 작업한다면 실행 담당을 정하세요. (계정을 나눌지는 아직 정하지 않았습니다.)

> [!NOTE]
> `apt-get` 설치 명령은 `# MANUAL 0` 표식을 입력하기 전에 실행했지만,
> 성격상 0단계 수동 명령이므로 집계에 포함합니다.

## 문서 재현 검토

> [!NOTE]
> **TODO:** 깨끗한 서버(또는 초기화한 서버)에서 이 장의 명령만 따라 해서 0단계가 통과하는지 확인할 것.
> 검토 날짜와 검토자(코드명), 막힌 곳을 기록한다. (체크리스트: "0단계 문서 재현 검토")

## 막혔을 때

[문제 해결](ch7_troubleshooting.md) 의 "0단계" 항목을 참고하세요.
