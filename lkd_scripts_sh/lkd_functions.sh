function log {
  if [[ $LOGGING_ON -ne 0 ]]
  then
    echo "[ $0 ] $1" | tee -a ./lkd_log
  else
    echo "[ $0 ] $1"
  fi
}

function docker_build {
  log "called $FUNCNAME" 
  docker build \
    -f $FILES/lkd_Dockerfile \
    --build-arg PROJECTA=$PROJECT \
    -t lkd-$PROJECT . || exit 1
}

function wipe_kernel {
  log "called $FUNCNAME" 
  ls -a | \
    grep -v -E "lkd_" | \
    grep -v -E "^(.|..|linux-$COMMIT.tar.gz|.git*|.docker*)\$" | \
    xargs rm -rf
}

function get_sources {
  log "called $FUNCNAME" 
  if [[ -f linux-$COMMIT.tar.gz ]]
  then
    log "Reusing existing sources"
  else
    log "Fetching sources"
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
    copy-out:    copy args from gust\n\
    setup:       runs full initial setup"
}

function docker_run {
  log "called $FUNCNAME" 
  docker run -it \
      --rm --cap-add=SYS_PTRACE \
      --security-opt seccomp=unconfined \
      -v $(pwd):/$PROJECT:Z \
      -v $(pwd)/$FILES/lkd_gdbinit:/home/dbg/.gdbinit:Z \
      --net host \
      --hostname "lkd-$PROJECT-container" \
      --name lkd-$PROJECT-container \
      lkd-$PROJECT
}
