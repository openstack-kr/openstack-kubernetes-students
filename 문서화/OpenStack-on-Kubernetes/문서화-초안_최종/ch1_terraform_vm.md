# 1단계. VM 4대 만들기 (Terraform + libvirt)

## 이 단계가 하는 일

빌린 서버 안에 **가상의 컴퓨터(VM) 4대를 코드로 만드는 단계**입니다.

- 서버는 건물이고, VM은 그 안에 만드는 방입니다. 이후 Kubernetes와 OpenStack은 이 방들 안에 설치됩니다.
- **libvirt/KVM** 이 실제로 VM을 만들고 돌려 주는 도구이고, **Terraform** 은 "VM을 이렇게 만들어 줘"라고 적은 파일(코드)을 읽어서 libvirt에게 시키는 도구입니다.
- 사람이 마우스로 하나씩 만들지 않고 코드로 만들면, 같은 환경을 몇 번이고 똑같이 다시 만들 수 있습니다. 이것이 이 프로젝트에서 "결과 일관성"을 재는 바탕입니다.

만들어지는 VM 4대는 다음과 같습니다.

| VM 이름 | 역할 | vCPU | 메모리 | 디스크 | 고정 주소 |
|---|---|---|---|---|---|
| cp | Kubernetes의 관리자 노드 (control plane) | 4 | 16GiB | 60GB | 192.168.100.10 |
| ctrl-worker | OpenStack 관리 서비스가 올라갈 노드 | 16 | 32GiB | 120GB | 192.168.100.11 |
| compute-1 | 사용자 VM을 돌릴 컴퓨트 노드 | 10 | 32GiB | 80GB | 192.168.100.21 |
| compute-2 | 컴퓨트 노드 (compute-1과 같은 사양) | 10 | 32GiB | 80GB | 192.168.100.22 |

합계는 vCPU 40개, 메모리 112GiB입니다. 서버 메모리가 125GiB라서 호스트에는 약 13GiB가 남습니다.
VM 디스크는 필요한 만큼만 쓰는 방식(thin)이라, 서버 디스크 여유(약 452GB)에 들어갑니다.

> [!NOTE]
> `192.168.100.x` 는 서버 안에서만 쓰는 **가상 주소**입니다. 인터넷에서는 접근할 수 없습니다.
> 컴퓨트 노드를 2대로 하는 이유는, 이후 검증에서 "컴퓨트가 2대 모두 정상"인지 확인하기 때문입니다.

## 선행 조건

- 0단계 점검과 도구 설치 통과 ([0단계](ch0_prerequisites.md))
- `lab` 계정으로 접속, `tmux` 세션 안에서 작업
- 서버 디스크 여유 약 350GB 이상, 메모리 약 125GiB (사양이 작으면 VM 사양을 줄이세요)

## 키트로 실행하기

> [!NOTE]
> **TODO:** 자동화 키트 완성 후 `make stage-1` 사용법을 채울 것.

## 설계: 무엇을 어떻게 만드는가

- **네트워크**: `openinfra-lab` 이라는 가상 네트워크(`192.168.100.0/24`, 서버가 인터넷 연결을 대신 해 주는 NAT 방식, 게이트웨이 `.1`)를 만듭니다. VM마다 MAC 주소와 IP를 짝지어 **고정 주소**를 줍니다. Kubespray가 "노드 IP가 바뀌지 않는다"는 전제로 동작하고, 반복 평가에서 같은 IP가 나와야 하기 때문입니다.
- **디스크**: Ubuntu 이미지를 저장소(풀)에 올려 **기준 볼륨** 하나로 두고, 노드마다 그것을 바탕으로 쓰는 디스크(thin qcow2)를 만듭니다.
- **cloud-init**: VM이 처음 켜질 때 계정(`kit`, sudo 가능, SSH 키 전용)과 호스트명을 자동으로 넣어 주는 설정을, 노드별 작은 디스크(ISO)로 만들어 VM에 붙입니다.
- **접속 키**: VM 접속용 키(`~/.ssh/id_vm_ed25519`)는 서버 안에서 만들고, 개인키는 서버 밖으로 내보내지 않습니다.
- **만들어지는 리소스 19개**: 풀 1, 네트워크 1, 기준 볼륨 1, 노드 디스크 4, cloud-init 디스크 4, cloud-init 볼륨 4, VM 4.

코드는 `~/openinfra-lab-kit/terraform` 에 두 파일로 나뉩니다.

- `versions.tf`: 도구와 provider(Terraform이 libvirt와 이야기하게 해 주는 부품) 버전을 고정합니다.
- `main.tf`: 만들 리소스를 정의합니다.

> [!NOTE]
> **TODO:** 저장소의 `versions.tf` / `main.tf` 핵심 부분(주석 포함)을 코드 블록으로 붙일 것.

> [!WARNING]
> **인터넷의 libvirt + Terraform 예제를 그대로 쓰지 마세요.**
> provider 0.9.x는 0.8 이전과 **문법이 다릅니다**. 예제가 대부분 옛 문법이라 동작하지 않습니다.
> 이 가이드는 예제 대신 provider가 스스로 알려 주는 속성 목록(스키마)을 보고 코드를 썼습니다.
>
> ```bash
> terraform providers schema -json > ~/logs/libvirt-schema-0.9.9.json
> ```
>
> 스키마로 확인한 사실은 다음과 같습니다.
>
> - `libvirt_volume` 에는 최상위 `format` 이 없고 `target.format.type` 으로 지정합니다.
> - `libvirt_cloudinit_disk` 에는 `pool` 이 없고 `path` 를 내보냅니다. 그 ISO를 `libvirt_volume` 으로 올려 VM에 붙입니다.
> - `.iso` 볼륨의 형식은 `raw` 가 아니라 `iso` 로 지정해야 합니다. (`raw` 로 쓰면 libvirt가 `iso` 로 인식해서, `plan` 이 계속 변경이 있다고 표시합니다.)
> - `libvirt_network` 는 `forward.mode`, `ips[].dhcp.hosts[]` (MAC, IP, 이름)로 고정 IP를 예약합니다.
> - `libvirt_domain` 의 디스크는 `source.volume` (풀과 볼륨)과 `target` (장치, 버스)으로, 네트워크 카드는 `mac.address` 와 `source.network.network` 로 지정합니다.

## 단계별로 따라 하기

### 1. 노드 이미지 준비

VM의 바탕이 될 Ubuntu 24.04(noble) 클라우드 이미지를 받고, **다운로드가 깨지지 않았는지 해시로 검증**합니다.

```bash
mkdir -p ~/images && cd ~/images
# noble 폴더의 날짜별 이미지를 받음 (날짜 폴더로 고정, 'current' 는 쓰지 않음)
# 이 가이드: 릴리스 20261017, noble-server-cloudimg-amd64.img (약 593MB)
sha256sum -c SHA256SUMS --ignore-missing    # "OK" 가 나와야 함
```

> [!WARNING]
> - 이미지 주소는 `/releases/24.04/` 가 아니라 `/noble/<날짜>/` 입니다. 앞의 주소는 안내 페이지로 바뀌어 목록이 비어 있습니다.
> - `current` 폴더는 날짜가 바뀌면 내용이 달라져 결과가 달라집니다. **날짜 폴더** 를 쓰고 해시로 검증하세요.

> [!NOTE]
> **TODO:** 실제 다운로드 명령(주소 전체)을 저장소 스크립트 기준으로 채울 것.

### 2. VM 만들기

```bash
cd ~/openinfra-lab-kit/terraform
# STAGE 1
# MANUAL 1
terraform init                 # provider 내려받기
terraform fmt                  # 코드 모양 정리
terraform validate             # 문법 검사
terraform plan -out=tfplan1    # 무엇이 만들어질지 미리 보기
terraform apply tfplan1        # 실제로 만들기
```

- 순서는 **validate → plan → apply** 입니다. `plan` 의 마지막 줄이 `Plan: 19 to add, 0 to change, 0 to destroy.` 인지 확인한 뒤 `apply` 하세요.
- `plan` 의 번호(`tfplan1` 등)는 시도마다 바꿔 쓰면 기록이 남아 좋습니다.
- VM이 정상이면 `apply` 에는 약 1분 30초가 걸립니다.

> [!WARNING]
> **VM 시작 단계에서 실패할 수 있습니다** (`Permission denied`). 이 가이드의 서버에서 가장 오래 걸린 문제였습니다.
> 아래 "VM 시작 실패: AppArmor" 를 먼저 읽고, 실패하기 전에 규칙을 넣어 두면 피할 수 있습니다.

### 3. VM 시작 실패: AppArmor

**증상**: `apply` 에서 풀, 네트워크, 볼륨, cloud-init 15개는 만들어졌는데 **VM 4대만** `Domain was defined but failed to start` 로 실패합니다.
메시지에는 `Could not open '.../noble-...base.qcow2': Permission denied` 가 있고, 4대가 거의 동시에(24ms 이내) 같은 파일에서 같은 오류를 냅니다.

**원인**: **AppArmor** (프로그램마다 "여기까지만 접근해도 된다"를 정해 두는 보안 장치)가 VM을 돌리는 QEMU의 디스크 접근을 막은 것으로 확인했습니다.

- libvirt는 VM을 켤 때마다 그 VM 전용 허용 목록(프로파일)을 만듭니다.
- 이 서버에서는 그 목록에 **디스크 이미지 경로가 빠져 있었고**, 그래서 디스크를 열지 못했습니다.
- 같은 종류의 문제(비표준 경로의 backing 파일이 허용 목록에 안 들어감)가 terraform-provider-libvirt 이슈 #126, #546과 Ubuntu 버그 #1644507에 보고되어 있습니다. 다만 이 서버에서 같은 메커니즘인지는 확인하지 못했습니다.

**해결 (권장)**: AppArmor를 켠 채로, 디스크 폴더를 허용하는 규칙 한 줄을 추가합니다.

```bash
sudo mkdir -p /etc/apparmor.d/local/abstractions
echo '/var/lib/libvirt/images/** rwk,' | sudo tee -a /etc/apparmor.d/local/abstractions/libvirt-qemu
```

이 줄은 "`/var/lib/libvirt/images` 폴더 아래의 모든 파일을 읽고(r) 쓰고(w) 잠가도(k) 된다"는 뜻입니다.
이 파일은 모든 VM의 허용 목록이 공통으로 읽는 **사용자 추가 규칙 파일**이라 패키지가 업데이트돼도 덮어쓰이지 않습니다.

규칙을 넣은 뒤 다시 `plan` → `apply` 하면 VM 4대가 시작됩니다. 확인은 다음과 같이 합니다.

```bash
sudo aa-status | grep -i libvirt     # QEMU 프로세스 4개가 각자 프로파일에 묶여 있음
virsh list --all                     # 4대 모두 running
```

> [!NOTE]
> 이 서버에서 보인 특이점입니다.
>
> - `journalctl -k` 에 AppArmor의 `DENIED` 줄이 **보이지 않았습니다.** (로그에 막힌 경로가 찍힌다고 알려져 있지만 여기서는 아니었습니다.) 그래서 로그로 원인을 확정하지 못했고, 허용 목록에 디스크 경로가 없는 것을 직접 확인했습니다.
> - `systemctl reload apparmor` 는 서비스가 꺼져 있어 실패했지만, 규칙은 **VM을 켤 때** 반영되어 동작했습니다.
> - 풀 경로를 `/var/lib/libvirt/images` 로 옮기는 것만으로는 해결되지 않았습니다.
> - 규칙을 지우고 다시 실패하는지 보는 **대조 실험은 아직 하지 않았습니다.** 그래서 "이 규칙이 원인을 해결했다"는 강한 정황이지만 엄밀히 증명한 것은 아닙니다.

> [!WARNING]
> 이 규칙은 **images 폴더 전체**를 허용합니다. 실습 서버에서는 괜찮지만, 필요한 파일만 정확히 허용하는 쪽이 더 안전합니다.
> (디스크를 `volume` 대신 `file` 경로로 지정하면 호스트 설정 없이 해결되는지는 시험할 예정입니다.)

**임시 우회 (권장하지 않음)**: `/etc/libvirt/qemu.conf` 에 `security_driver = "none"` 을 넣고 `libvirtd` 를 재시작하면 VM이 시작됩니다.
다만 이것은 **libvirt가 VM에 붙이는 AppArmor 규칙을 모두 끄는 것**이라 호스트와 VM 사이의 방어가 하나 줄어듭니다.
꼭 써야 한다면 먼저 백업하고, 나중에 반드시 되돌리세요.

```bash
sudo cp /etc/libvirt/qemu.conf /etc/libvirt/qemu.conf.bak      # 우회 전에 백업
# ... 우회를 되돌릴 때 ...
sudo cp /etc/libvirt/qemu.conf.bak /etc/libvirt/qemu.conf
sudo systemctl restart libvirtd
sudo grep -c '^security_driver' /etc/libvirt/qemu.conf          # 0 이면 우회가 없는 상태
```

> [!NOTE]
> `-parallelism=1` (VM을 한 대씩 순서대로 시작)로 바꿔도 같은 오류가 납니다. 동시 시작이 원인이 아니므로 해결책이 아닙니다.

## 기대 결과

```text
Apply complete! Resources: 19 added, 0 changed, 0 destroyed.
```

위 한 줄이 나오고 VM 4대가 `running` 이면 성공입니다. (AppArmor 문제를 겪은 경우에는 `4 added` 로 나뉘어 끝날 수 있습니다.)

## 확인 방법

```bash
virsh list --all                           # VM 4대 모두 running
virsh net-dhcp-leases openinfra-lab        # 고정 IP 4개 (.10, .11, .21, .22)
ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 hostname     # cp 라고 나옴
for ip in 10 11 21 22; do
  ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.$ip \
    'hostname; timedatectl | grep synchronized'
done                                       # 4대 모두 호스트명이 맞고 synchronized: yes
ssh -i ~/.ssh/id_vm_ed25519 kit@192.168.100.10 \
  'curl -s -o /dev/null -w "%{http_code}\n" https://github.com'   # 200 (VM의 외부 통신)
```

VM 안의 실제 사양(설정값 / 측정값)은 다음과 같았습니다.

| 노드 | 메모리 (설정 / 실제) | 디스크 (설정 / 실제) |
|---|---|---|
| cp | 16GiB / 15GiB | 60GB / 58G |
| ctrl-worker | 32GiB / 31GiB | 120GB / 116G |
| compute-1, compute-2 | 32GiB / 31GiB | 80GB / 77G |

## 이 단계에서 겪은 오류와 주의사항

| # | 증상 | 원인 | 해결 |
|---|---|---|---|
| 1 | 인터넷의 libvirt Terraform 예제가 동작하지 않음 | provider 0.9.x 문법이 0.8 이전과 다름 | `terraform providers schema -json` 의 스키마로 속성명 확인 |
| 2 | `/releases/24.04/` 에 이미지 목록이 없음 | 경로가 Cloud Image Locator 안내 페이지로 바뀜 | `/noble/<날짜>/` 에서 받고 `SHA256SUMS` 로 검증 |
| 3 | `plan` 이 `4 to change` 를 계속 표시 | `.iso` 볼륨 형식을 `raw` 로 썼으나 libvirt는 `iso` 로 인식 | 코드의 형식을 `iso` 로 수정 |
| 4 | VM 시작 실패 (`Permission denied`) | AppArmor가 VM의 기준 이미지 접근을 막음 | 규칙 한 줄 추가 (위 3번 항목) |
| 5 | 풀 경로를 바꿨더니 `plan` 이 `4 add, 1 change` | 풀 경로는 교체가 아니라 in-place 변경으로 잡힘. 볼륨은 옛 경로에 남아 불일치 | 전부 `destroy` 후 새 경로로 재생성 |
| 6 | `Saved plan is stale` | 부분 적용으로 상태가 바뀌어 저장해 둔 계획을 다시 쓸 수 없음 | 계획을 새로 만들어 적용 |

> [!WARNING]
> - **풀 경로(이미지 폴더)는 처음부터 정하고 바꾸지 마세요.** 바꾸면 풀과 볼륨을 함께 `destroy` 하고 다시 만들어야 합니다.
> - **VM을 지우고 같은 IP로 다시 만들면** SSH가 `REMOTE HOST IDENTIFICATION HAS CHANGED` 로 접속을 거부합니다. VM의 호스트 키가 새로 생겼기 때문이며, `ssh-keygen -R <IP>` 로 옛 키를 지우면 됩니다. (2단계의 Ansible은 실습 환경 편의를 위해 호스트 키 확인을 끕니다.)
> - `terraform.tfstate` 와 `.terraform/` 은 서버 정보와 상태가 들어 있어서 **GitHub에 올리지 않습니다.**
> - 실패한 `apply` 이후에도 일부 리소스(풀, 네트워크, 볼륨)는 만들어진 채로 남습니다. 다시 `plan` 하면 남은 것만 만들어집니다.

## 문서 재현 검토

> [!NOTE]
> **TODO:** 깨끗한 서버에서 이 장의 명령만 따라 해서 VM 4대가 뜨는지 확인할 것. 특히 AppArmor 규칙을 **먼저** 넣고 `apply` 했을 때 실패 없이 한 번에 되는지 확인한다. (체크리스트: "1단계 문서 재현 검토")

## 막혔을 때

[문제 해결](ch7_troubleshooting.md) 의 "1단계" 항목을 참고하세요.
