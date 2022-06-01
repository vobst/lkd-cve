#!/usr/bin/bash

# Variables you want to change
# name of the kernel debugging project you are working on
export PROJECT=dirtypipe
# path/to/your/ssh_key
export PATH_SSH_KEY=/home/kali/.ssh/id_rsa
# path/to/your/ssh_pubkey
export PATH_SSH=/home/kali/.ssh/id_rsa.pub
# path/to/your/ssh_config
export PATH_SSH_CONF=/home/kali/.ssh/config
# the commit you want to build
export COMMIT=e783362eb54cd99b2cac8b3a9aeac942e6f6ac07
# save logs to file
export LOGGING_ON=1

# Variables you may not want to change
export PATH_SSHD_CONF=$(pwd)/lkd_sshd_config
export IMG=lkd_qemu_image.qcow2
export DIR=mount-point.dir

source lkd_functions.sh

log "---new run $PROJECT---"

case $1 in
  dotfiles)
    create_dotfiles
  ;;
  rebuild)
    # dangerous, wipes anything but lkd_* files
    wipe_kernel
    get_sources
    ./lkd_build_kernel.sh || exit 1
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
    ./lkd_run_qemu.sh $2
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
    sudo -E ./lkd_create_root_fs.sh || exit 1
  ;;
  setup)
    log "case $1" 
    sudo true || exit 1
    docker_build
    get_sources
    ./lkd_build_kernel.sh && \
    sudo -E ./lkd_create_root_fs.sh || exit 1
    ln -sf /${PROJECT}/scripts/gdb/vmlinux-gdb.py vmlinux-gdb.py
    ln -sf /${PROJECT}/lkd_scripts_gdb/lkd_gdb_load.py lkd_gdb_load.py
    update_ssh-config
    create_dotfiles
  ;;
  *)
    print_usage
  ;;
esac
    
exit 0
