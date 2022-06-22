function log {
  if [[ $LOGGING_ON -ne 0 ]]
  then
    echo "[ $0 ] $1" | tee -a $KERNEL/lkd_log
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
  rm -rf syzkaller && \
  git clone -4 --depth 1 https://github.com/google/syzkaller syzkaller || exit 1
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
  make $SYZKALLER_MAKE_CMD bin/syz-extract && \
  cd $KERNEL || exit 1
}

function get_go_sources {
  log "called $FUNCNAME" 
  if [[ -f go${GOVERSION}.linux-amd64.tar.gz ]]
  then
    log "Reusing existing go toolchain"
  else
    log "Fetching new go toolchain"
    wget -4 https://dl.google.com/go/go${GOVERSION}.linux-amd64.tar.gz
  fi
  rm -rf go/ && \
  tar xf go${GOVERSION}.linux-amd64.tar.gz || exit 1
}

function get_kernel_sources {
  log "called $FUNCNAME" 
  if [[ -f linux-$COMMIT.tar.gz ]]
  then
    log "Reusing existing kernel sources"
  else
    log "Fetching new kernel sources"
    wget -4 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-$COMMIT.tar.gz
  fi
  tar xf linux-$COMMIT.tar.gz && \
  rsync -a linux-$COMMIT/ $(pwd)/  && \
  rm -rf linux-$COMMIT/ || exit 1
}

function update_ssh_config {
  log "called $FUNCNAME" 
  if [[ ! -f $PATH_SSH_KEY ]]
  then
    log "Generating new ssh keys"
    ssh-keygen -f "$HOME/.ssh/id_rsa" -t rsa -N ''
  else
    log "Reusing existing ssh keys"
  fi
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
  echo -e "Options:\n\
    install (all|docker|deps_syzkaller|deps_kernel)\n\
      Installs the project's dependencies. Only for Debian/Ubuntu/Kali.\n\
    rebuild-kernel [syzkaller]\n\
      Rebuilds kernel from COMMIT. Optional parameters influence\n\
      config, default is defconfig plus debug info.\n\
    rebuild-syzkaller\n\
      Rebuilds syzkaller to apply costum patches.\n\
    dotfiles:    re-creates dotfiles\n\
    clean-fs:    wipes remnants of failed fs creation\n\
    rootfs [syzkaller|eBPF]\n\
      Rebuilds rootfs. Defaults to rootfs for debugging.\n\
    symlinks:    re-create symlinks to gdb scripts\n\
    setup [syzkaller|eBPF]\n\
      Runs a full initial setup. Assumes that dependencies are\n\
      installed. Defaults to debugging setup.
    copy-in:     copy args to guest:root/\n\
    copy-out:    copy args from guest:root/\n\
    gdb:         launches gdb inside container\n\
    kill:        kills QEMU instance\n\
    run [debug|syzkaller]: spins up QEMU instance. Optionally with \n\
      or gdbstub or for syzakller testing.\n\
    debug:       spins up container\n\
    docker:      re-builds container\n\
    fuzz:	 start syzkaller"
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

function install_deps_syzkaller {
  log "called $FUNCNAME" 
  sudo apt-get update
  sudo apt-get install -y -q \
    libc6-dev-i386 \
    linux-libc-dev \
    gcc-aarch64-linux-gnu \
    gcc-arm-linux-gnueabi \
    gcc-powerpc64le-linux-gnu \
    gcc-mips64el-linux-gnuabi64 || true
  sudo apt-get install -y -q g++-aarch64-linux-gnu || true
  sudo apt-get install -y -q g++-powerpc64le-linux-gnu || true
  sudo apt-get install -y -q g++-arm-linux-gnueabi || true
  sudo apt-get install -y -q g++-mips64el-linux-gnuabi64 || true
  sudo apt-get install -y -q g++-s390x-linux-gnu || true
  sudo apt-get install -y -q g++-riscv64-linux-gnu || true
  sudo apt-get install -y -q g++ || true
  [ -z "$(shell which python)" -a -n "$(shell which python3)" ] && \
    sudo apt-get install -y -q python-is-python3 || true
  sudo apt-get install -y -q clang-tidy || true
  sudo apt-get install -y -q clang clang-format ragel
  GO111MODULE=off go get -u golang.org/x/tools/cmd/goyacc
}

function install_deps_kernel {
  log "called $FUNCNAME" 
  sudo apt-get update && \
  sudo apt-get install -y -q \
    build-essential \
    rsync \
    git \
    qemu-system-x86 \
    debootstrap \
    bc \
    openssl \
    libncurses-dev \
    gawk \
    flex \
    bison \
    libssl-dev \
    dkms \
    libelf-dev \
    libudev-dev \
    libpci-dev \
    libiberty-dev \
    autoconf || exit 1
}

function maybe_install_docker {
  log "called $FUNCNAME" 
  if docker version; then
    log "Docker is already installed"
  else
    log "Installing docker"
    install_deps_docker
    install_docker
  fi
}

function install_deps_docker {
  log "called $FUNCNAME" 
  sudo apt-get update && \
  sudo apt-get install -y -q \
    ca-certificates \
    curl \
    gnupg \
    lsb-release || exit 1
}

function install_docker {
  curl -4 -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  sudo apt-get update && \
  sudo apt-get -y -q install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin && \
  sudo usermod -aG docker $USER && \
  newgrp docker && \
  sudo systemctl start docker || exit 1
}
