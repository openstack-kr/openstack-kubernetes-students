# 문제 해결

수동 구축 중에 **실제로 겪은** 문제를 단계별로 모았습니다. 항목은 모두 같은 형식입니다.

```rst
증상
   (화면에 나온 메시지나 관찰한 현상)
발생 단계
   (0~6단계 중 어디인지)
원인
   (키트/설정 원인인지, 서버 환경 같은 외부 원인인지)
해결
   (명령 또는 절차)
참고
   (자세한 설명이 있는 장)
```

> [!NOTE]
> **원인 구분.** *설정·순서 오류* 는 우리 쪽 설정이나 명령 순서의 문제, *환경* 은 서버·방화벽·네트워크처럼
> 우리가 직접 고칠 수 없는 쪽의 문제입니다. 자동화 키트의 성공률을 셀 때 이 둘을 나눠서 세기 위한 분류입니다.

## 공통

### 로그와 기록 위치

- `~/logs/` : 설치 로그(예: `kubespray-cluster-*.txt`), 환경 확인 출력, 스키마 파일
- 셸 명령 기록: `history` (시각 포함, `# STAGE n` / `# MANUAL n` 표식으로 구분)
- **로그는 서버에만 있으므로, 단계가 끝날 때마다 내 컴퓨터로 백업하세요.** (아래 "작업 환경")

> [!NOTE]
> **TODO:** 키트가 출력하는 실패 메시지 형식(단계, 항목, 가능한 원인, 로그 위치)을 키트 완성 후 설명할 것.

### 작업 환경 (모든 단계 공통)

**`scp` 가 지문 확인에서 멈춤**

- **원인**: 서버 안에서 서버로 복사하려고 함 (환경: 실행 위치 오류).
- **해결**: `scp` 는 **내 컴퓨터** 의 터미널에서 실행합니다. `scp -r lab@<서버 주소>:~/openinfra-lab-kit ~/Desktop/openinfra-backup/`

**zsh에서 `no matches found`**

- **원인**: zsh가 `*` 를 먼저 해석함.
- **해결**: 주소를 작은따옴표로 감쌉니다. `'lab@<서버 주소>:~/history-backup-*.txt'`

**zsh에서 `# NOTE ...` 줄이 `command not found`**

- **원인**: Mac의 zsh는 터미널에서 `#` 줄을 주석으로 처리하지 않음.
- **해결**: 표식은 서버(bash)에서만 입력합니다.

**`tmux attach -t kit` 이 `no sessions` 로 나옴**

- **원인**: 서버가 아닌 곳에서 실행했거나, 다른 계정으로 접속했거나, 세션이 없음 (tmux 세션은 계정마다 따로).
- **해결**: `lab` 계정으로 접속했는지 확인하고, 없으면 `tmux new -s kit` 으로 새로 만듭니다.

**SSH가 `Operation timed out`**

- **원인**: 내 쪽 네트워크나 방화벽 (서버가 재부팅된 것은 아니었음). 이 가이드에서는 원인을 확인하지 못했습니다.
- **해결**: 휴대폰 핫스팟 등 다른 네트워크로 바꾸고 `nc -vz -w 5 <서버 주소> 22` (Mac) 또는 `Test-NetConnection <서버 주소> -Port 22` (Windows)로 22번 포트를 확인합니다. 서버 업체 방화벽에서 `ssh / tcp / 22` 허용이 살아 있는지도 확인합니다. (삭제하거나 해제하지 마세요.)

**새 컴퓨터에서 `Permission denied (publickey)`**

- **원인**: `lab` 계정은 키로만 접속하는데 그 컴퓨터의 공개키가 서버에 등록되지 않음.
- **해결**: 그 컴퓨터의 공개키(`.pub`)를 서버 관리자가 `lab` 의 `~/.ssh/authorized_keys` 에 등록합니다. 개인키는 공유하지 않습니다.

**`ssh-keygen` 이 `already exists, Overwrite?` 를 물음**

- **해결**: `n` 을 입력해 기존 키를 지키는 것이 맞습니다.

## 0단계

**서버 시계가 맞지 않음 (`Not synchronised`, `Reach 0`)**

- **발생 단계**: 0단계 (시간 동기화 확인)
- **원인**: 환경. 방화벽의 "나가는 목적지 포트"에 UDP 123이 없어서 시간 서버의 응답이 차단됨. 서버 시계가 실제보다 366.4초(약 6분 6초) 늦었음.
- **해결**: 방화벽에 `ntp / udp / 123` 허용을 등록한 뒤 `sudo chronyc burst 4/4`, `sudo chronyc makestep`. 등록 후 약 25분 뒤 `Reach` 가 377, `System clock synchronized: yes` 로 유지됨.
- **진단 순서**: ① `chronyc sources` 에서 `Reach` 가 0 → ② `getent hosts` 로 서버 이름이 풀리는지 확인(DNS 문제 아님) → ③ python으로 UDP 123에 직접 질의해서 timeout 확인(chrony 설정 문제 아님) → ④ HTTPS(443), DNS(53)는 정상 → ⑤ 방화벽 목록 확인.
- **참고**: [0단계](ch0_prerequisites.md)

**`git clone git@github.com:...` 이 멈춤**

- **원인**: 환경. 방화벽의 나가는 포트에 22번이 없음.
- **해결**: `https://github.com/...` 주소를 사용합니다.

**도구 설치 후 `virsh` 에 권한 오류**

- **원인**: `libvirt` 그룹이 현재 로그인 세션에 적용되지 않음.
- **해결**: 접속을 끊었다가 다시 접속합니다. (`groups` 에 `libvirt` 가 보여야 함)

**`ModuleNotFoundError` 또는 `ansible: command not found`**

- **원인**: 가상환경을 켜지 않았음.
- **해결**: `source ~/venv-kubespray/bin/activate` (프롬프트 앞에 `(venv-kubespray)` 확인)

## 1단계

**인터넷의 libvirt Terraform 예제가 동작하지 않음**

- **원인**: 설정·순서 오류. provider 0.9.x 문법이 0.8 이전과 다름.
- **해결**: `terraform providers schema -json` 의 스키마로 속성 이름을 확인해서 코드를 씁니다. **참고**: [1단계](ch1_terraform_vm.md)

**이미지 경로 `/releases/24.04/` 에 목록이 비어 있음**

- **원인**: 환경. 경로가 안내 페이지로 바뀜.
- **해결**: `/noble/<날짜>/` 에서 받고 `SHA256SUMS` 와 `sha256sum -c` 로 검증합니다. `current` 폴더는 쓰지 않습니다.

**`plan` 이 `.iso` 볼륨을 계속 변경으로 표시 (`4 to change`)**

- **원인**: 설정·순서 오류. 볼륨 형식을 `raw` 로 썼으나 libvirt는 `.iso` 를 `iso` 로 인식.
- **해결**: 코드의 해당 볼륨 형식을 `iso` 로 지정합니다.

**VM 시작 실패: `Could not open '...base.qcow2': Permission denied` (`Domain was defined but failed to start`)**

- **발생 단계**: 1단계 (`terraform apply`). 풀, 네트워크, 볼륨, cloud-init 15개는 만들어지고 VM 4대만 실패.
- **원인**: 환경. AppArmor의 VM별 허용 목록에 디스크 경로가 빠져서 QEMU가 기준 이미지를 열지 못함. (`journalctl -k` 에는 `DENIED` 가 보이지 않았음.)
- **해결**: AppArmor를 켠 채로 `/etc/apparmor.d/local/abstractions/libvirt-qemu` 에 `/var/lib/libvirt/images/** rwk,` 한 줄을 추가하고 다시 `apply`. 임시 우회(`security_driver = "none"`)는 보안을 낮추므로 권장하지 않으며, 썼다면 `qemu.conf.bak` 으로 되돌립니다.
- **참고**: [1단계](ch1_terraform_vm.md)
- **기각한 가설**: 동시 시작 (`-parallelism=1` 에서도 동일), 코드·이미지 문제 (`validate`, `plan` 통과, `qemu-img info` 정상), `qemu.conf` 설정 오류, 풀 경로 (`/var/lib/libvirt/images` 로 옮겨도 동일).

**풀 경로를 바꿨더니 `plan` 이 `4 add, 1 change`**

- **원인**: 설정·순서 오류. 풀 경로는 교체 대상이 아니라 in-place 변경으로 잡힘. 볼륨은 옛 경로에 남아 불일치.
- **해결**: 풀과 볼륨을 `destroy` 한 뒤 새 경로로 재생성합니다. 풀 경로는 처음부터 정하고 바꾸지 마세요.

**`Saved plan is stale`**

- **원인**: 설정·순서 오류. 부분 적용으로 상태가 바뀌어 저장해 둔 계획을 다시 쓸 수 없음.
- **해결**: `terraform plan -out=...` 으로 계획을 새로 만들어 적용합니다.

**VM을 지우고 다시 만든 뒤 SSH에서 `REMOTE HOST IDENTIFICATION HAS CHANGED`**

- **원인**: 설정·순서 오류. 같은 IP의 VM이 새 호스트 키를 가짐.
- **해결**: `ssh-keygen -R <IP>` 또는 Ansible `host_key_checking = False` (실습 환경 한정).

## 2단계

**`ansible all -m shell` 이 `FAILED` 로 표시되는데 출력은 정상**

- **원인**: `grep -c` 가 0건일 때 종료 코드 1을 돌려줘서 Ansible이 실패로 표시함. 실제 실패가 아님.
- **해결**: 무시해도 됩니다. 필요하면 명령 끝에 `|| true` 를 붙입니다.

**노드 자기 이름이 `127.0.1.1` 로 풀림**

- **원인**: cloud-init의 `127.0.1.1 <호스트명>` 기본 줄이 노드 주소 줄보다 앞에 있음.
- **해결**: 인벤토리의 노드 줄에 `ip=`, `access_ip=` 를 명시합니다. (확정된 문제가 아니라 예방 조치)

## 3단계

**`kube_version` 이 값이 아니라 식으로 보임**

- **원인**: Kubespray가 `kubelet_checksums` 표의 첫 항목을 계산해서 기본값으로 씀.
- **해결**: 체크섬 파일(`roles/kubespray_defaults/vars/main/checksums.yml`)에서 첫 항목을 확인하고, `v` 없는 `kube_version: 1.35.4` 로 설정에 고정합니다.

**버전 확인 스크립트가 `FileNotFoundError`**

- **원인**: 경로가 `defaults/main` 이 아니라 `vars/main` 임.
- **해결**: `grep -rn '^kubelet_checksums' ~/kubespray/roles | head` 로 위치를 찾습니다.

**`v1.35.4 있음: False`**

- **원인**: 목록의 버전 형식에 `v` 가 없음.
- **해결**: `v` 를 빼고 비교·고정합니다.

## 4단계

**차트를 버전 없이 받으면 2026.2 개발판이 설치됨**

- **원인**: 설정·순서 오류. Helm 저장소의 최신 차트가 개발판.
- **해결**: 커밋 해시가 붙은 버전으로 10개 차트를 모두 고정합니다. **참고**: [4단계](ch4_prereqs.md)

**`helm search ... | grep` 이 아무것도 안 나옴**

- **원인**: 패턴 앞에 공백을 넣어서 일치하는 줄이 없음. 실제로는 2026.1 차트가 32개 있음.
- **해결**: `grep -E '2026\.1\.'` (앞 공백 없이).

**클러스터에 스토리지 클래스가 없음 (`No resources found`)**

- **원인**: 설정·순서 오류. Kubespray의 local-path가 기본으로 꺼져 있음.
- **해결**: `addons.yml` 에서 `local_path_provisioner_enabled: true`, `local_path_provisioner_storage_class: "general"` 로 설정하고 Kubespray를 다시 실행합니다.

**`addons.yml` 에 같은 변수가 두 번 나옴**

- **원인**: 견본의 `false` 줄을 그대로 두고 끝에 `true` 를 덧붙임.
- **해결**: 덧붙인 줄을 지우고 견본의 줄을 `true` 로 수정합니다.

**볼륨 요청(PVC)이 `Pending` 으로 보임**

- **원인**: 정상. 스토리지 클래스가 `WaitForFirstConsumer` 라 파드가 노드에 배치될 때 볼륨이 만들어짐.
- **해결**: 해당 PVC를 쓰는 파드가 뜨면 `Bound` 가 됩니다.

**시험 파드·볼륨이 남아 있음**

- **해결**: `kubectl delete pod,pvc sc-test -n openstack`

## 미해결 항목

| 항목 | 상태 |
|---|---|
| 이미지의 `latest-` 태그 (다이제스트 고정 방식) | 5단계 전에 결정 |
| AppArmor 규칙 제거 시 재실패 여부(대조 실험) | 구축 완료 후 실시 |
| 디스크를 `file` 경로로 지정했을 때 호스트 설정 없이 되는지 | 시험 예정 |
| 서버 SSH 접속 불가의 원인 | 확인 못 함 |
| Helm 4.x와 OpenStack-Helm의 호환 | 확인 안 함 (Helm 3.18.4 사용 중) |
| 서버 재부팅 후 VM과 규칙이 유지되는지 | 확인 안 함 |
