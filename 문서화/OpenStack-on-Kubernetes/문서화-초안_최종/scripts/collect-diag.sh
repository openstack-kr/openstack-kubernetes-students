#!/usr/bin/env bash
# OpenInfra Lab Kit - 진단 로그 수집기 (읽기 전용: 시스템을 바꾸지 않습니다)
# 사용: sudo bash collect-diag.sh [출력폴더]   (기본: ./diag-<시각>)
# 실패 "직후"에 실행하세요. 결과 폴더를 tar.gz 로 묶어 이슈/문서에 첨부합니다.
set -u
OUT="${1:-./diag-$(date +%Y%m%d-%H%M%S)}"
IMG_DIR="${IMG_DIR:-/var/lib/libvirt/images}"   # VM 디스크를 두는 경로
mkdir -p "$OUT"
run() { # run <파일이름> <명령...> : 명령과 결과를 파일에 저장 (실패해도 계속)
  local f="$OUT/$1"; shift
  { echo "\$ $*"; echo "# $(date -Is)"; "$@" 2>&1; echo "# exit=$?"; } >"$f"
}
sh_run() { local f="$OUT/$1"; shift; { echo "\$ $*"; bash -c "$*" 2>&1; } >"$f"; }

# 1. 환경
run 01-os.txt cat /etc/os-release
run 02-kernel.txt uname -a
sh_run 03-versions.txt 'libvirtd --version; qemu-system-x86_64 --version | head -1; terraform version; ansible --version | head -1; apparmor_parser --version | head -1'
sh_run 04-resources.txt 'nproc; free -h; df -h; lsmod | grep -E "kvm|nbd" ; ls -l /dev/kvm'

# 2. AppArmor (VM 시작 거부의 1순위 용의자)
run 10-aa-status.txt aa-status
sh_run 11-aa-denied-journal.txt 'journalctl -k --no-pager | grep -iE "apparmor|denied" | tail -200'
sh_run 12-aa-denied-audit.txt 'journalctl --no-pager _TRANSPORT=audit 2>/dev/null | grep -i apparmor | tail -200; ls -l /var/log/audit 2>/dev/null; grep -i apparmor /var/log/audit/audit.log 2>/dev/null | tail -200'
sh_run 13-aa-denied-syslog.txt 'grep -i "apparmor=\"DENIED\"" /var/log/syslog /var/log/kern.log 2>/dev/null | tail -200'
sh_run 14-aa-dmesg.txt 'dmesg | grep -iE "apparmor|denied" | tail -200'
sh_run 15-aa-libvirt-rules.txt 'ls -l /etc/apparmor.d/libvirt/ /etc/apparmor.d/local/abstractions/ 2>&1; echo ---; cat /etc/apparmor.d/local/abstractions/libvirt-qemu 2>&1; echo ---; ls /etc/apparmor.d/libvirt/libvirt-*.files 2>/dev/null | head'
sh_run 16-aa-service.txt 'systemctl is-active apparmor; systemctl status apparmor --no-pager | head -20'

# 3. 디스크 경로 / 소유권 (멘토 지적: 비표준 경로, 소유자)
sh_run 20-image-path.txt "namei -l '$IMG_DIR' 2>&1; echo ---; ls -ldZ '$IMG_DIR' 2>&1; ls -l '$IMG_DIR' | head -30; echo ---; stat -c '%U:%G %a %n' '$IMG_DIR'/* 2>&1 | head -30"
sh_run 21-qemu-user.txt 'grep -E "^(user|group|security_driver|dynamic_ownership)" /etc/libvirt/qemu.conf; id libvirt-qemu; id kvm 2>&1; ls -l /etc/libvirt/qemu.conf*'
sh_run 22-pools.txt 'virsh pool-list --all; for p in $(virsh pool-list --all --name); do echo "== $p"; virsh pool-dumpxml "$p" | grep -E "path|name"; done'

# 4. libvirt / VM
sh_run 30-virsh.txt 'virsh list --all; virsh net-list --all; virsh net-dhcp-leases openinfra-lab 2>&1'
sh_run 31-libvirtd-journal.txt 'journalctl -u libvirtd -u virtqemud --no-pager -n 300 2>&1'
sh_run 32-qemu-vm-logs.txt 'for f in /var/log/libvirt/qemu/*.log; do echo "=== $f"; tail -40 "$f"; done'

# 5. 네트워크 / 시간 (NTP UDP 123 이슈)
sh_run 40-network.txt 'ip -br a; ip r; ss -tlnp | head -30; iptables -S 2>&1 | head -40; nft list ruleset 2>&1 | head -60'
sh_run 41-time.txt 'timedatectl; chronyc tracking 2>&1; chronyc sources 2>&1'

# 6. 도구별 최근 기록 (있을 때만)
sh_run 50-terraform.txt 'ls -la; terraform state list 2>&1 | head -50'
sh_run 51-k8s.txt 'kubectl get nodes -o wide 2>&1; kubectl get pods -A 2>&1 | grep -v Running | head -50; kubectl get events -A --sort-by=.lastTimestamp 2>&1 | tail -40'

# 7. 민감정보 가리기 (공인 IP, 토큰, 키)
PUB_IP="$(curl -s --max-time 3 https://ifconfig.me 2>/dev/null || true)"
find "$OUT" -type f -exec sed -i -E \
  -e 's/(token|password|secret|PRIVATE KEY)[^ ]*/\1=<REDACTED>/Ig' \
  -e 's/-----BEGIN [A-Z ]*PRIVATE KEY-----.*/<REDACTED KEY>/g' {} +
[ -n "$PUB_IP" ] && find "$OUT" -type f -exec sed -i "s/$PUB_IP/<서버 공인IP>/g" {} +

tar czf "$OUT.tar.gz" -C "$(dirname "$OUT")" "$(basename "$OUT")"
echo "완료: $OUT.tar.gz  (올리기 전에 내용을 직접 한 번 훑어보세요)"