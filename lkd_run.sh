#!/usr/bin/bash

# Variables you want to change
# name of the kernel debugging project you are working on
#export PROJECT=dirtypipe
#export PROJECT=cve-2021-22555
#export PROJECT=devel
export PROJECT=eBPF

# the commit you want to build
# mainline kernel
# export COMMIT=$(git ls-remote --heads https://github.com/torvalds/linux | grep -oE "[0-9a-f]{4}+")
# dirtypipe
export COMMIT=e783362eb54cd99b2cac8b3a9aeac942e6f6ac07
# CVE-2021-22555
# export COMMIT=d163a925ebbc6eb5b562b0f1d72c7e817aa75c40
# devel 
#export COMMIT=e783362eb54cd99b2cac8b3a9aeac942e6f6ac07

# path/to/your/ssh_key
export PATH_SSH_KEY=${HOME}/.ssh/id_rsa
# path/to/your/ssh_pubkey
export PATH_SSH=${HOME}/.ssh/id_rsa.pub
# path/to/your/ssh_config
export PATH_SSH_CONF=${HOME}/.ssh/config

# save logs to file
export LOGGING_ON=1

# Variables you may not want to change
export IMG=lkd_qemu_image.qcow2
export DIR=mount-point.dir
export FILES=lkd_files
export SCRIPTS=lkd_scripts_sh
export EXAMPLES=$(pwd)/lkd_examples
export PATH_SSHD_CONF=$(pwd)/$FILES/lkd_sshd_config

export GOVERSION="1.17.6"
export GOROOT=$(pwd)/go
export PATH="${PATH}:${GOROOT}/bin"

export KERNEL=$(pwd)

export SYZKALLER="$(pwd)/syzkaller"
export FUZZER_BASE="/tmp/syzkaller"
export SYZKALLER_MAKE_CMD="HOSTOS=linux HOSTARCH=amd64 TARGETOS=linux TARGETVMARCH=amd64 TARGETARCH=386"
export PATH="${PATH}:${SYZKALLER}/bin"

source $SCRIPTS/lkd_functions.sh

log "---new run of $PROJECT---"

case $1 in
  install)
    log "case $1" 
    case $2 in
      all)
	log "case $2" 
	maybe_install_docker
	install_deps_syzkaller
	install_deps_kernel
      ;;
      docker)
	log "case $2" 
	maybe_install_docker
      ;;
      deps_syzkaller)
	log "case $2" 
	[ -d "go" ] || get_go_sources
	install_deps_syzkaller
      ;;
      deps_kernel)
	log "case $2" 
	install_deps_kernel
      ;;
      *)
	print_usage
      ;;
    esac
  ;;
  rebuild-kernel)
    log "case $1" 
    log "Hope you pushed your progress..." 
    wipe_all_but_lkd
    get_kernel_sources
    ./$SCRIPTS/lkd_build_kernel.sh $2 || exit 1
    create_symlinks
    create_dotfiles
  ;;
  rebuild-syzkaller)
    log "case $1" 
    get_go_sources
    GO111MODULE=off go get -u golang.org/x/tools/cmd/goyacc
    get_syzkaller_sources
    build_syzkaller
    cp $EXAMPLES/$PROJECT/netfilter.txt \
      $SYZKALLER/sys/linux/netfilter.txt && \
    cd $SYZKALLER || exit 1
    [ -d "/tmp/linux" ] && log "Have /tmp/linux" || \
      ( log "Need new /tmp/linux" && \
      git clone -4 --depth 1 https://github.com/torvalds/linux /tmp/linux )
    ./bin/syz-extract -sourcedir /tmp/linux -build \
      netfilter.txt && \
    make $SYZKALLER_MAKE_CMD generate && \
    build_syzkaller && cd $KERNEL || exit 1    
  ;;
  dotfiles)
    log "case $1" 
    create_dotfiles
  ;;
  clean-fs)
    log "case $1" 
    sudo umount /mnt/$DIR && sudo rmdir /mnt/$DIR || exit 1
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
    get_kernel_sources
    update_ssh_config
    ./$SCRIPTS/lkd_build_kernel.sh $2 && \
    sudo -E ./$SCRIPTS/lkd_create_root_fs.sh $2 || exit 1
    create_symlinks
    create_dotfiles
  ;;
  cp-in)
    log "case $1" 
    scp -q $EXAMPLES/$PROJECT/* lkd_qemu:/root
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
  fuzz)
    log "case $1" 
    log "Config is: $(envsubst < $EXAMPLES/$PROJECT/syz_mngr_conf | sed -E "s/[ \t]+//g" | tr "\n" " ")"
    mkdir -p $FUZZER_BASE && cd $FUZZER_BASE && \
    $SYZKALLER/bin/syz-manager --config <(envsubst < $EXAMPLES/$PROJECT/syz_mngr_conf)
  ;;
  *)
    print_usage
  ;;
esac
    
exit 0
