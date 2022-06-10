function log {
  if [[ $LOGGING_ON -ne 0 ]]
  then
    echo "[ $0 ] $1" | tee -a ./lkd_log
  else
    echo "[ $0 ] $1"
  fi
}

function create_symlinks {
  ln -sf /${PROJECT}/scripts/gdb/vmlinux-gdb.py vmlinux-gdb.py
  ln -sf /${PROJECT}/lkd_scripts_gdb/lkd_gdb_load.py lkd_gdb_load.py
}

function docker_build {
  log "called $FUNCNAME" 
  docker build \
    -f $FILES/lkd_Dockerfile \
    --build-arg PROJECTA=$PROJECT \
    -t lkd-$PROJECT . || exit 1
}

function wipe_all_but_lkd {
  log "called $FUNCNAME" 
  ls -a | \
    grep -v -E "^(lkd_.*|README.md|LICENSE)\$" | \
    grep -v -E "^(.|..|linux-$COMMIT.tar.gz|go${GOVERSION}.linux-amd64.tar.gz|.git*|.docker*)\$" | \
    xargs rm -rf
}

function get_sources {
  log "called $FUNCNAME" 
  get_kernel_sources
  if [[ $# -eq 1 || $1 == "syzkaller" ]]
  then
    get_go_sources
    get_syzkaller_sources
  fi
}

function get_syzkaller_sources {
  log "called $FUNCNAME" 
  git clone --depth 1 https://github.com/google/syzkaller syzkaller && \
  rm -rf syzkaller/.git* || exit 1
}

function build_addons {
  log "called $FUNCNAME" 
  if [[ $# -eq 1 || $1 == "syzkaller" ]]
  then
    build_syzkaller
  fi
}

function build_syzkaller {
  log "called $FUNCNAME" 
  cd $SYZKALLER && \
  make $SYZKALLER_MAKE_CMD && \
  cd $KERNEL || exit 1
}

function get_go_sources {
  log "called $FUNCNAME" 
  if [[ -f go${GOVERSION}.linux-amd64.tar.gz ]]
  then
    log "Reusing existing go toolchain"
  else
    log "Fetching new go toolchain"
    wget https://dl.google.com/go/go${GOVERSION}.linux-amd64.tar.gz
  fi
  tar xf go${GOVERSION}.linux-amd64.tar.gz || exit 1
}

function get_kernel_sources {
  log "called $FUNCNAME" 
  if [[ -f linux-$COMMIT.tar.gz ]]
  then
    log "Reusing existing kernel sources"
  else
    log "Fetching new kernel sources"
    wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-$COMMIT.tar.gz
  fi
  tar xf linux-$COMMIT.tar.gz && \
  rsync -a linux-$COMMIT/ $(pwd)/  && \
  rm -rf linux-$COMMIT/ || exit 1
}

function update_ssh-config {
  log "called $FUNCNAME" 
  if [[ -z $(grep -E "^Host lkd_qemu$" ${PATH_SSH_CONF}) ]]
  then
    log "Updating ssh config"
    echo -en "\nHost lkd_qemu\n\tHostName localhost\n\tPort 2222\n\tUser root\n\tIdentityFile ${PATH_SSH_KEY}\n\tStrictHostKeyChecking false" >> ${PATH_SSH_CONF} || exit 1
  else
    log "ssh config is up to date"
  fi
}

function create_dotfiles {
  log "called $FUNCNAME" 
  # create dockerignore
  ls -a | grep -v lkd  | grep -v -E "^(.|..)$" > .dockerignore && \
  echo "lkd_qemu_image.qcow2" >> .dockerignore || exit 1

  # create gitignore
  cp .dockerignore .gitignore && \
  echo -e ".dockerignore\n\
    lkd_vm.log\n\
    lkd_log\n\
    fs/\n\
    mm/\n\
    lkd_gdb_load.py\n\
    .gdb_history\n\
    go/\n\
    *.pyc" | \
  sed -E "s/[ ]+//g" >> .gitignore || exit 1
}

function print_usage {
  log "called $FUNCNAME" 
  echo -e "Options: \n\
    dotfiles:    re-creates dotfiles\n\
    rebuild:     rebuilds kernel from COMMIT\n\
    gdb:         launches gdb inside container\n\
    clean-fs:    wipes remnants of failed fs creation\n\
    kill:        kills QEMU instance\n\
    run [debug]: spins up QEMU instance [with gdbstub]\n\
    debug:       spins up container\n\
    docker:      re-builds container\n\
    rootfs:      re-builds rootfs\n\
    copy-in:     copy args to guest\n\
    copy-out:    copy args from guest\n\
    setup:       runs full initial setup\n\
    symlinks:    re-create symlinks to gdb scripts"
}

function docker_run {
  log "called $FUNCNAME" 
  docker run -it \
      --rm \
      --privileged \
      -v $(pwd):/$PROJECT:Z \
      -v $(pwd)/$FILES/lkd_gdbinit:/home/dbg/.gdbinit:Z \
      --net host \
      --pid host \
      --hostname "lkd-$PROJECT-container" \
      --name lkd-$PROJECT-container \
      lkd-$PROJECT
}
