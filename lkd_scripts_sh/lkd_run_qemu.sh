#!/usr/bin/env bash

set -ex

source $SCRIPTS/lkd_functions.sh

CMD="\
-kernel $KERNEL/arch/x86_64/boot/bzImage \
-drive file=$IMG,format=raw \
--nographic \
-m 4096 \
-net nic,model=e1000 \
-nic user,hostfwd=tcp:127.0.0.1:2222-:22"
KCMD="root=/dev/sda rw console=ttyS0 nokaslr"
SMP="-smp 1"

if [[ $# -eq 1 ]]
then
  log "Running QEMU with option $1"
  case $1 in
    debug)
      log "case $1" 
      CMD="$CMD -gdb tcp::1234"
    ;;
    eBPF)
      log "case $1"
      SMP="-smp 2"
      KCMD="$KCMD lsm=bpf"
    ;;
    syzkaller)
      log "case $1" 
      CMD="$CMD -pidfile vm.pid"
      SMP="-smp 2"
      KCMD="console=ttyS0 root=/dev/sda earlyprintk=serial net.ifnames=0"
    ;;
    *)
      log "received unknown option $1" 
      exit 1
    ;;
  esac
else
  true
fi
CMD="$CMD $SMP -append"

if [[ -n "$(ss -ln | grep '^tcp.*:2222')" ]]
then
	echo "port 2222 is already in use! change the port or stop the corresponding process"
	exit 1
fi

# w/ KVM support
# does not quite work: https://lkml.iu.edu/hypermail/linux/kernel/2103.2/00282.html
# single-stepping gets interrupted by e.g. timers

# qemu-system-x86_64 -kernel arch/x86_64/boot/bzImage -append "root=/dev/sda rw console=ttyS0 nokaslr" -drive file=./lkd_qemu_image.qcow2,format=raw --enable-kvm -cpu host --nographic -m 4096 -net nic,model=virtio -net user,hostfwd=tcp:127.0.0.1:2222-:22 -smp 1 $DEBUG |& tee lkd_vm.log

log "Starting QEMU with command line $CMD $KCMD"
qemu-system-x86_64 $CMD "$KCMD" |& tee lkd_vm.log

# reset the terminal
reset
