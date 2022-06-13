#!/usr/bin/bash

set -ex

# Variables you want to change
# name of the kernel debugging project you are working on
#export PROJECT=dirtypipe
export PROJECT=cve-2021-22555
#export PROJECT=devel

# the commit you want to build
# dirtypipe
# export COMMIT=e783362eb54cd99b2cac8b3a9aeac942e6f6ac07
# CVE-2021-22555
export COMMIT=d163a925ebbc6eb5b562b0f1d72c7e817aa75c40
# devel 
#export COMMIT=e783362eb54cd99b2cac8b3a9aeac942e6f6ac07

# path/to/your/ssh_key
export PATH_SSH_KEY=/home/kali/.ssh/id_rsa
# path/to/your/ssh_pubkey
export PATH_SSH=/home/kali/.ssh/id_rsa.pub
# path/to/your/ssh_config
export PATH_SSH_CONF=/home/kali/.ssh/config

# save logs to file
export LOGGING_ON=1

# Variables you may not want to change
export IMG=lkd_qemu_image.qcow2
export DIR=mount-point.dir
export FILES=lkd_files
export SCRIPTS=lkd_scripts_sh
export EXAMPLES=lkd_examples
export PATH_SSHD_CONF=$(pwd)/$FILES/lkd_sshd_config

export GOVERSION="1.17.6"
export GOROOT=$(pwd)/go
export PATH="${PATH}:${GOROOT}/bin"

export KERNEL=$(pwd)

export SYZKALLER="$(pwd)/syzkaller"
export SYZKALLER_MAKE_CMD="HOSTOS=linux HOSTARCH=amd64 TARGETOS=linux TARGETVMARCH=amd64 TARGETARCH=386"
export PATH="${PATH}:${SYZKALLER}/bin"

source $SCRIPTS/lkd_functions.sh

log "---new run $PROJECT---"

case $1 in
  rebuild-syzkaller)
    log "case $1" 
    get_go_sources
    get_syzkaller_sources
    build_syzkaller
    cp $EXAMPLES/$PROJECT/netfilter.txt \
      $SYZKALLER/sys/linux/netfilter.txt && \
    cd $SYZKALLER && \
    ./bin/syz-extract -sourcedir /tmp/linux -build \
      netfilter.txt && \
    make $SYZKALLER_MAKE_CMD generate && \
    build_syzkaller && cd $KERNEL || exit 1    
  ;;
  cp-in)
    log "case $1" 
    scp -q $EXAMPLES/$PROJECT/* lkd_qemu:/root
  ;;
  dotfiles)
    log "case $1" 
    create_dotfiles
  ;;
  rebuild)
    log "case $1" 
    log "Hope you pushed your progress..." 
    wipe_all_but_lkd
    get_sources $2
    ./$SCRIPTS/lkd_build_kernel.sh $2 || exit 1
    create_symlinks
    create_dotfiles
  ;;
  build-addons)
    build_addons $2
  ;;
  clean-fs)
    log "case $1" 
    sudo umount $DIR && rmdir $DIR || exit 1
  ;;
  gdb)
    log "case $1" 
    gdb -q -x lkd_examples/${PROJECT}/${PROJECT}.py
  ;;
  kill)
    log "case $1" 
    kill -SIGTERM $(pidof qemu-system-x86_64)
  ;;
  run)
    log "case $1" 
    ./$SCRIPTS/lkd_run_qemu.sh $2
  ;;
  debug)
    log "case $1" 
    docker_run
  ;;
  docker)
    log "case $1" 
    docker_build
  ;;
  rootfs)
    log "case $1" 
    sudo -E ./$SCRIPTS/lkd_create_root_fs.sh $2 || exit 1
  ;;
  symlinks)
    create_symlinks
  ;;
  setup)
    log "case $1" 
    sudo true || exit 1
    docker_build
    get_sources $2
    ./$SCRIPTS/lkd_build_kernel.sh $2 && \
    sudo -E ./$SCRIPTS/lkd_create_root_fs.sh $2 || exit 1
    create_symlinks
    update_ssh-config
    create_dotfiles
  ;;
  *)
    print_usage
  ;;
esac
    
exit 0
