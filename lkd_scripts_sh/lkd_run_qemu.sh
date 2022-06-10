#!/usr/bin/env bash

set -e

if [[ $# -eq 1 && $1 == "debug" ]]
then
  DEBUG="-gdb tcp::1234";
else
    DEBUG=""
fi

if [[ -n "$(ss -ln | grep '^tcp.*:2222')" ]]
then
	echo "port 2222 is already in use! change the port or stop the corresponding process"
	exit 1
fi

# w/ KVM support
# does not quite work: https://lkml.iu.edu/hypermail/linux/kernel/2103.2/00282.html
# single-stepping gets interrupted by e.g. timers

# qemu-system-x86_64 -kernel arch/x86_64/boot/bzImage -append "root=/dev/sda rw console=ttyS0 nokaslr" -drive file=./lkd_qemu_image.qcow2,format=raw --enable-kvm -cpu host --nographic -m 4096 -net nic,model=virtio -net user,hostfwd=tcp:127.0.0.1:2222-:22 -smp 1 $DEBUG |& tee lkd_vm.log

# w/o KVM support
qemu-system-x86_64 \
-kernel arch/x86_64/boot/bzImage \
-append "root=/dev/sda rw console=ttyS0 nokaslr" \
-drive file=./lkd_qemu_image.qcow2,format=raw \
--nographic -m 4096 \
-nic user,hostfwd=tcp:127.0.0.1:2222-:22 \
-smp 1 $DEBUG \
|& tee lkd_vm.log

# reset the terminal
reset
