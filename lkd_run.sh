#!/usr/bin/bash

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
export PATH_SSHD_CONF=$(pwd)/$FILES/lkd_sshd_config

source $SCRIPTS/lkd_functions.sh

log "---new run $PROJECT---"

case $1 in
  dotfiles)
    create_dotfiles
  ;;
  rebuild)
    # dangerous, wipes anything but lkd_* files
    wipe_kernel
    get_sources
    ./$SCRIPTS/lkd_build_kernel.sh || exit 1
    ln -sf /${PROJECT}/scripts/gdb/vmlinux-gdb.py vmlinux-gdb.py
    ln -sf /${PROJECT}/lkd_scripts_gdb/lkd_gdb_load.py lkd_gdb_load.py
    create_dotfiles
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
    sudo -E ./$SCRIPTS/lkd_create_root_fs.sh || exit 1
  ;;
  symlinks)
    create_symlinks
  ;;
  setup)
    log "case $1" 
    sudo true || exit 1
    docker_build
    get_sources
    ./$SCRIPTS/lkd_build_kernel.sh && \
    sudo -E ./$SCRIPTS/lkd_create_root_fs.sh || exit 1
    create_symlinks
    update_ssh-config
    create_dotfiles
  ;;
  *)
    print_usage
  ;;
esac
    
exit 0
