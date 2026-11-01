#!/usr/bin/env bash
# 1단계(Terraform apply) 전에 실행하는 사전 점검. 기본은 "점검만" 합니다.
# 사용: sudo bash preflight.sh            # 점검만
#       sudo bash preflight.sh --fix      # AppArmor 허용 규칙을 추가 (멱등: 여러 번 실행해도 같음)
set -u
IMG_DIR="${IMG_DIR:-/var/lib/libvirt/images}"
RULE_FILE=/etc/apparmor.d/local/abstractions/libvirt-qemu
RULE="${IMG_DIR%/}/** rwk,"
FIX=0; [ "${1:-}" = "--fix" ] && FIX=1
fail=0
ok()   { echo "[ OK ] $*"; }
bad()  { echo "[FAIL] $*"; fail=1; }
info() { echo "[INFO] $*"; }

[ -c /dev/kvm ] && ok "/dev/kvm 있음" || bad "/dev/kvm 없음 (KVM 가상화 불가)"
systemctl is-active --quiet libvirtd 2>/dev/null || systemctl is-active --quiet virtqemud 2>/dev/null \
  && ok "libvirt 실행 중" || bad "libvirt 가 실행 중이 아님"

# 디스크 경로
if [ -d "$IMG_DIR" ]; then
  ok "디스크 경로 존재: $IMG_DIR (소유: $(stat -c '%U:%G' "$IMG_DIR"))"
else bad "디스크 경로 없음: $IMG_DIR"; fi
case "$IMG_DIR" in
  /var/lib/libvirt/images*) ok "libvirt 기본 경로 → AppArmor 기본 허용 대상";;
  *) info "비표준 경로($IMG_DIR) → AppArmor 허용 규칙이 반드시 필요";;
esac

# AppArmor
if systemctl is-active --quiet apparmor 2>/dev/null || aa-status --enabled 2>/dev/null; then
  info "AppArmor 사용 중"
  if grep -qxF "$RULE" "$RULE_FILE" 2>/dev/null; then ok "허용 규칙 있음: $RULE"
  else
    case "$IMG_DIR" in /var/lib/libvirt/images*) ok "기본 경로라 추가 규칙 불필요할 수 있음 (실패하면 --fix)";;
    *) if [ $FIX -eq 1 ]; then
         mkdir -p "$(dirname "$RULE_FILE")"; echo "$RULE" >> "$RULE_FILE"; ok "규칙 추가: $RULE"
       else bad "허용 규칙 없음 → --fix 로 추가 ($RULE)"; fi;;
    esac
  fi
else info "AppArmor 비활성"; fi

# 방화벽/시간
timeout 3 bash -c 'echo > /dev/udp/pool.ntp.org/123' 2>/dev/null && ok "UDP 123 송신 가능(참고용)" || info "UDP 123 확인 불가: 서버 방화벽 정책 확인"
free -g | awk '/Mem:/{ if ($2<64) print "[WARN] 메모리 "$2"GiB: VM 합계(약 112GiB 할당)보다 작음"; else print "[ OK ] 메모리 "$2"GiB" }'

[ $fail -eq 0 ] && echo "=> 사전 점검 통과" || { echo "=> 실패 항목이 있습니다. 위 [FAIL] 을 해결하세요."; exit 1; }