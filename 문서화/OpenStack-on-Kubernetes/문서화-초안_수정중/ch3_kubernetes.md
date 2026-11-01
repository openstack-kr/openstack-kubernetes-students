# 3단계. Kubernetes 구축 (Kubespray)

## 이 단계가 하는 일

VM 4대를 하나의 **Kubernetes 클러스터**로 묶는 단계입니다.

- **Kubernetes** 는 여러 대의 컴퓨터 위에서 프로그램(컨테이너)을 자동으로 배치하고 관리해 주는 시스템입니다. 이후 5단계에서 OpenStack의 각 서비스가 컨테이너로 이 위에 올라갑니다.
- **Kubespray** 는 Kubernetes를 설치해 주는 Ansible 묶음입니다. 2단계에서 만든 노드 목록을 그대로 읽어서, 노드마다 컨테이너 런타임(containerd), 저장소(etcd), 관리 구성요소, 네트워크 플러그인(Calico)을 설치합니다.
- 우리가 고른 버전은 Kubespray v2.31.0이고, 이것이 설치하는 Kubernetes는 1.35.4입니다.

> [!NOTE]
> Kubernetes 1.35는 OpenStack-Helm 공식 지원 범위(1.33~1.35)의 **상한**입니다.
> 문제가 생기면 1.34로 내리는 것이 예비안입니다. 또한 Kubespray와 OpenStack-Helm의 조합은
> 공식 검증 대상이 아니라서, 이 가이드의 실제 설치 결과가 검증 기록입니다.

## 선행 조건

- 2단계 완료 (`ansible all -m ping` 4대 통과, 사전 설정 완료)
- `tmux` 안에서, `(venv-kubespray)` 가상환경이 켜진 상태
- VM에서 외부 레지스트리(이미지 저장소)에 접속 가능

## 키트로 실행하기

> [!NOTE]
> **TODO:** 자동화 키트 완성 후 `make stage-3` 사용법을 채울 것.

## 단계별로 따라 하기

### 1. 우리 클러스터 설정 폴더 만들기

Kubespray가 제공하는 설정 견본(`sample`)을 복사해서 우리 설정으로 씁니다.
설정을 우리 저장소 안에 두면 Kubespray 본체(`~/kubespray`)는 건드리지 않고 설정만 관리할 수 있습니다.

```bash
# STAGE 3
# MANUAL 3
mkdir -p ~/openinfra-lab-kit/kubespray/inventory
cp -rfp ~/kubespray/inventory/sample ~/openinfra-lab-kit/kubespray/inventory/openinfra
```

### 2. 노드 목록 가져오기

```bash
cp ~/openinfra-lab-kit/ansible/inventory.ini \
   ~/openinfra-lab-kit/kubespray/inventory/openinfra/inventory.ini
grep -c 'access_ip=' ~/openinfra-lab-kit/kubespray/inventory/openinfra/inventory.ini   # 4
```

`4` 가 나와야 합니다. 0이면 2단계의 `ip`/`access_ip` 추가가 적용되지 않은 것입니다.

그리고 접속 정보를 파일 끝에 덧붙입니다.

```ini
[all:vars]
ansible_user=kit
ansible_ssh_private_key_file=/home/lab/.ssh/id_vm_ed25519
```

> [!NOTE]
> **TODO:** 저장소의 `[all:vars]` 전체(`ansible_ssh_common_args` 포함)를 그대로 붙일 것.

### 3. 설치할 버전과 기본값 확인

```bash
# NOTE 3: 기본값 확인
grep -rnE '^(kube_version|kube_network_plugin|container_manager):' \
  ~/kubespray/roles/kubespray_defaults ~/openinfra-lab-kit/kubespray/inventory/openinfra
```

- `kube_network_plugin` 은 `calico`, `container_manager` 는 `containerd` 입니다. 바꾸지 않습니다.
- `kube_version` 은 **숫자가 아니라 계산식**으로 되어 있습니다. (`kubelet_checksums` 표의 첫 번째 항목을 쓰라는 뜻입니다.)

> [!WARNING]
> **설치 버전은 직접 고정하세요.** 기본값은 Kubespray 버전이 바뀌면 같이 바뀌어,
> 같은 구축이 시점에 따라 다른 결과가 될 수 있습니다.

실제 기본값이 무엇인지 확인합니다.

```bash
python3 - <<'EOF'
import yaml
d = yaml.safe_load(open('/home/lab/kubespray/roles/kubespray_defaults/vars/main/checksums.yml'))
k = list(d['kubelet_checksums']['amd64'])
print('기본값(첫 항목):', k[0])
EOF
```

`기본값(첫 항목): 1.35.4` 가 나오면 릴리스 노트와 일치합니다.

> [!WARNING]
> - 이 파일의 위치는 `defaults/main` 이 아니라 **`vars/main/checksums.yml`** 입니다. (경로가 틀리면 파일을 못 찾는다는 오류가 납니다. 서버에는 영향이 없습니다.)
> - 목록의 버전 형식은 `v` 없는 `1.35.4` 입니다. `v1.35.4` 로 찾으면 `False` 가 나오지만 의미 없는 결과입니다. 고정할 때도 `v` 를 붙이면 "목록에 없는 버전"으로 판단되어 설치 시작 때 실패할 수 있습니다.

그다음 버전을 고정합니다.

```bash
echo 'kube_version: 1.35.4' >> ~/openinfra-lab-kit/kubespray/inventory/openinfra/group_vars/k8s_cluster/k8s-cluster.yml
grep -c '^kube_version' ~/openinfra-lab-kit/kubespray/inventory/openinfra/group_vars/k8s_cluster/k8s-cluster.yml   # 1
```

`1` 이 나와야 합니다. 2 이상이면 같은 줄을 두 번 넣은 것이니 하나를 지우세요.

### 4. 설치 전 점검 (읽기 전용)

```bash
cd ~/openinfra-lab-kit/ansible
ansible -i ~/openinfra-lab-kit/kubespray/inventory/openinfra/inventory.ini all -m ping      # 4대 pong
[ -n "$TMUX" ] && echo "tmux 안" || echo "tmux 밖"                                           # tmux 안
```

`tmux 안` 이어야 합니다. 설치에는 10~30분이 걸리고, **접속이 끊기면 설치가 중단**되기 때문입니다.

### 5. 설치 실행

```bash
cd ~/kubespray
time ansible-playbook \
  -i ~/openinfra-lab-kit/kubespray/inventory/openinfra/inventory.ini \
  --become cluster.yml 2>&1 | tee ~/logs/kubespray-cluster-$(date +%m%d-%H%M).txt
```

- `cluster.yml` 은 Kubespray의 "클러스터 설치" 플레이북입니다.
- `--become` 은 VM 안에서 관리자 권한으로 실행한다는 뜻입니다. (`kit` 계정은 비밀번호 없는 sudo입니다.)
- `time` 은 걸린 시간을 재고, `tee` 는 화면 출력을 파일에도 저장합니다. **소요 시간과 로그는 논문 자료이므로 꼭 남기세요.**

## 기대 결과

설치가 끝나면 마지막에 **PLAY RECAP** 가 나옵니다. 이 가이드에서는 다음과 같았습니다.

| 확인 항목 | 결과 |
|---|---|
| PLAY RECAP | 4대 모두 `failed=0`, `unreachable=0` |
| cp의 `ignored=4` | 실패해도 계속 진행하게 정의된 작업이 4개 있었다는 뜻. `failed=0` 이면 정상입니다. |
| 소요 시간 | `real` 10분 55초 (가장 오래 걸린 작업은 이미지·바이너리 다운로드, 최대 38초) |
| 노드 4대 | 모두 `Ready`, 버전 v1.35.4 |
| 노드 내부 IP | 모두 `192.168.100.x` (루프백 주소가 아님) |
| 컨테이너 런타임 | `containerd://2.2.3` |

## 확인 방법

클러스터를 조작하는 `kubectl` 설정은 cp 노드 안에 있으므로, 우선 cp에서 실행하는 방식으로 확인합니다.

```bash
# NOTE 3: 설치 결과 확인
ansible -i ~/openinfra-lab-kit/kubespray/inventory/openinfra/inventory.ini kube_control_plane --become \
  -m shell -a 'kubectl get nodes -o wide --kubeconfig /etc/kubernetes/admin.conf'
ansible -i ~/openinfra-lab-kit/kubespray/inventory/openinfra/inventory.ini kube_control_plane --become \
  -m shell -a 'kubectl get pods -A --kubeconfig /etc/kubernetes/admin.conf'
```

- 노드 4대가 `Ready` 여야 합니다.
- 파드(Pod)는 모두 `Running` (또는 `Completed`) 이고 `READY` 칸의 분자와 분모가 같아야 합니다(예: `1/1`). `CrashLoopBackOff`, `Pending`, `0/1` 이 보이면 문제입니다.
- 워커 노드의 `ROLES` 칸이 `<none>` 인 것은 정상입니다. 역할 레이블은 4단계에서 붙입니다.

## 이 단계에서 겪은 오류와 주의사항

| # | 증상 | 원인 | 해결 |
|---|---|---|---|
| 1 | `kube_version` 을 grep으로 찾았더니 값이 아니라 식이 나옴 | 값이 글자로 적혀 있지 않고 `kubelet_checksums` 표의 첫 항목을 계산하는 식 | 체크섬 파일에서 첫 항목을 직접 읽어 1.35.4 확인 후 설정에 고정 |
| 2 | 파이썬 확인 시 `v1.35.4 있음: False` | 목록의 버전 형식에 `v` 가 없음 | `v` 없는 `1.35.4` 로 고정 |

> [!NOTE]
> - 이 단계에서는 설치 자체에서 실패한 것이 없습니다. 사전 점검(버전 고정, 노드 IP 명시, 외부 접속 확인)이 효과가 있었습니다.
> - 설치 중 이미지를 받으므로 **방화벽에서 외부 레지스트리가 열려 있어야** 합니다. 이 가이드의 서버는 막힌 곳이 없었습니다.
> - Kubespray를 다시 실행하면 이미 된 작업은 건너뛰고 바뀐 부분만 적용됩니다(4단계의 스토리지 설정 때 사용).
> - `kubectl` 에 `--kubeconfig /etc/kubernetes/admin.conf` 를 붙이지 않으면 cp 안에서도 권한 오류가 날 수 있습니다.

## 문서 재현 검토

> [!NOTE]
> **TODO:** 깨끗한 VM 4대에서 이 장만 따라 해서 노드 4대 Ready까지 되는지 확인할 것. (체크리스트: "3단계 문서 재현 검토")

## 막혔을 때

[문제 해결](ch7_troubleshooting.md) 의 "3단계" 항목을 참고하세요.
