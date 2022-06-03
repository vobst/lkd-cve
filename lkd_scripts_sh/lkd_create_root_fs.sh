#!/usr/bin/bash

if [ "$EUID" -ne 0 ]
then
  echo "Please run as root"
  exit 1
fi

source $SCRIPTS/lkd_functions.sh

log "Creating rootfs" && \
ROOT_PASSWD_HASH=$(openssl passwd -1 test) && \
qemu-img create $IMG 5g && \
mkfs.ext2 $IMG && \
mkdir $DIR && \
mount -o loop $IMG $DIR && \
log "Begin bootstrapping" && \
debootstrap --arch amd64 \
--include=build-essential,gcc-multilib,vim,openssh-server,make,sudo,nftables,iptables \
bullseye $DIR && \
log "Begin fs modifications" && \
INSTALL_MOD_PATH=$(pwd)/$DIR make modules_install && \
sed -i -e "s#root:\*#root:${ROOT_PASSWD_HASH}#" $DIR/etc/shadow && \
echo "lkd-debian-qemu" > $DIR/etc/hostname && \
echo "127.0.0.1       lkd-debian-qemu" >> $DIR/etc/hosts && \
echo -e "auto enp0s3\niface enp0s3 inet dhcp" >> $DIR/etc/network/interfaces && \
mkdir $DIR/root/.ssh && \
cat $PATH_SSH > $DIR/root/.ssh/authorized_keys && \
cp $PATH_SSHD_CONF $DIR/etc/ssh/ && \
log "Begin teardown" && \
umount $DIR && \
rmdir $DIR && chmod 777 $IMG && exit 0 || \
umount $DIR && rmdir $DIR && exit 1

exit 1
