#!/usr/bin/env bash

# Variables you want to change
# name of the kernel debugging project you are working on
export PROJECT=dev
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

# make sure that we have sudo later so nothing times out
sudo true || exit 1

function log {
  if [[ $LOGGING_ON -ne 0 ]]
  then
    echo "$1" | tee -a /lkd_run.log
  else
    echo "$1"
  fi
}

function docker_build {
  docker build \
    -f lkd_Dockerfile \
    --build-arg PROJECTA=$PROJECT \
    -t lkd-$PROJECT . || exit 1
}

function get_sources {
  wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-$COMMIT.tar.gz && \
  tar xf linux-$COMMIT.tar.gz && \
  rsync -a linux-$COMMIT/ $(pwd)/  && \
  rm -rf linux-$COMMIT* || exit 1
}

function update_ssh-config {
  if [[ -z $(grep -E "^Host lkd_qemu$" ${PATH_SSH_CONF}) ]]
  then
    echo -en "\nHost lkd_qemu\n\tHostName localhost\n\tPort 2222\n\tUser root\n\tIdentityFile ${PATH_SSH_KEY}\n\tStrictHostKeyChecking false" >> ${PATH_SSH_CONF} || exit 1
  fi
}

function create_dotfiles {
  # create dockerignore
  ls -a | grep -v lkd  | grep -v -E "^(.|..)$" > .dockerignore && \
  echo "lkd_qemu_image.qcow2" >> .dockerignore || exit 1

  # create gitignore
  cp .dockerignore .gitignore && \
  echo -e ".dockerignore\nlkd_vm.log\nfs/\nmm/" >> .gitignore || exit 1
}

function print_usage {
  echo "Options: gdb, kill, run, debug, docker, rootfs, setup"
}

function docker_run {
  docker run -it \
      --rm --cap-add=SYS_PTRACE \
      --security-opt seccomp=unconfined \
      -v $(pwd):/$PROJECT:Z \
      -v $(pwd)/lkd_gdbinit:/home/dbg/.gdbinit:Z \
      --net host \
      --hostname "lkd-$PROJECT-container" \
      --name lkd-$PROJECT-container \
      lkd-$PROJECT
}


case $1 in
  gdb)
    gdb -q -x lkd_${PROJECT}_files/lkd_${PROJECT}_gdb.py
  ;;
  kill)
    kill -SIGTERM $(pidof qemu-system-x86_64)
  ;;
  run)
    ./lkd_run_qemu.sh
  ;;
  debug)
    docker_run
  ;;
  docker)
    docker_build
  ;;
  rootfs)
    sudo ./lkd_create_root_fs.sh || exit 1
  ;;
  setup)
    docker_build
    get_sources
    ./lkd_build_kernel.sh && \
    sudo ./lkd_create_root_fs.sh || exit 1
    ln -sf /${PROJECT}/scripts/gdb/vmlinux-gdb.py vmlinux-gdb.py
    ln -s /${PROJECT}/lkd_scripts_gdb/lkd_gdb_load.py lkd_gdb_load.py
    update_ssh-config
    create_dotfiles
  ;;
  *)
    print_usage
  ;;
esac
    
exit 0
