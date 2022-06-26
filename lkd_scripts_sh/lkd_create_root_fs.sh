#!/usr/bin/bash

if [ "$EUID" -ne 0 ]
then
  echo "Please run as root"
  exit 1
fi

source $SCRIPTS/lkd_functions.sh

if [[ $# -eq 1 && $1 == "syzkaller" ]]
then
  log "Building a root fs for syzkaller"
  PKGS='openssh-server,curl,tar,gcc,libc6-dev,time,strace,sudo,less,psmisc,selinux-utils,policycoreutils,checkpolicy,selinux-policy-default,firmware-atheros,debian-ports-archive-keyring,make,sysbench,git,vim,tmux,usbutils,tcpdump'
  DEBARCH=i386
  RELEASE=stretch
elif [[ $# -eq 1 && $1 == "eBPF" ]]
then
  log "Building a root fs for playing with eBPF"
  PKGS="strace,bpfcc-tools,bpfcc-introspection,python3-bpfcc,libbpfcc,libbpfcc-dev,bpftrace,bpftool,binutils,clang,libelf-dev,zlib1g-dev"
  DEBARCH=amd64
  RELEASE=bookworm
  GIT_CLONE="libbpf/libbpf-bootstrap iovisor/bcc iovisor/bpftrace"
else
  log "Building a normal rootfs"
  DEBARCH=amd64
  RELEASE=bullseye
fi

PKGS="$PKGS,build-essential,gcc-multilib,vim,git,openssh-server,make,sudo,ca-certificates,curl"
DIR=/mnt/$DIR
ROOT_PASSWD_HASH=$(openssl passwd -1 test) 
SEEK=5g
DEBOOTSTRAP_PARAMS="--arch=$DEBARCH --include=$PKGS --components=main,contrib,non-free $RELEASE $DIR"


log "Cleanup and preparation"
rm -rf $DIR && \
mkdir -p $DIR && \
chmod 0755 $DIR || exit 1

log "Creating img and mounting it"
qemu-img create $IMG $SEEK && \
mkfs.ext4 $IMG && \
mount -o loop $IMG $DIR || exit 1

log "Begin bootstrapping"
debootstrap $DEBOOTSTRAP_PARAMS || exit 1

log "Begin common root fs modifications"
log "Install kernel modules"
INSTALL_MOD_PATH="$DIR" make modules_install && \
log "System customizations"
sed -i -e "s#root:\*#root:${ROOT_PASSWD_HASH}#" $DIR/etc/shadow && \
echo "lkd-debian-qemu" > $DIR/etc/hostname && \
echo "127.0.0.1       lkd-debian-qemu" >> $DIR/etc/hosts && \
echo '/dev/root / ext4 defaults 0 0' >> $DIR/etc/fstab && \
echo "nameserver 8.8.8.8" >> $DIR/etc/resolve.conf && \
echo -e "auto enp0s3\niface enp0s3 inet dhcp" >> $DIR/etc/network/interfaces && \
log "Setup ssh"
mkdir $DIR/root/.ssh && \
cat $PATH_SSH > $DIR/root/.ssh/authorized_keys && \
cp $PATH_SSHD_CONF $DIR/etc/ssh/ || exit 1
log "Clone git repos"
for repo in $GIT_CLONE;
do
  REPO=$repo
  log "cloning $REPO"
  git clone https://github.com/$REPO $DIR/root/$REPO || exit 1
done

if [[ $# -eq 1 && $1 == "syzkaller" ]]
then
  log "Modifying the root fs for syzkaller"
  echo 'T0:23:respawn:/sbin/getty -L ttyS0 115200 vt100' >> $DIR/etc/inittab && \
  printf '\nauto eth0\niface eth0 inet dhcp\n' >> $DIR/etc/network/interfaces && \
  echo 'debugfs /sys/kernel/debug debugfs defaults 0 0' >> $DIR/etc/fstab && \
  echo 'securityfs /sys/kernel/security securityfs defaults 0 0' >> $DIR/etc/fstab && \
  echo 'configfs /sys/kernel/config/ configfs defaults 0 0' >> $DIR/etc/fstab && \
  echo 'binfmt_misc /proc/sys/fs/binfmt_misc binfmt_misc defaults 0 0' >> $DIR/etc/fstab || exit 1
elif [[ $# -eq 1 && $1 == "eBPF" ]]
then
  log "Modifying the root fs for eBPF"
else
  log "No further root fs modifications required"
fi

log "Begin teardown"
umount $DIR && \
rmdir $DIR && chmod 777 $IMG || exit 1

exit 0
