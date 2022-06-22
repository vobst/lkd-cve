#!/usr/bin/env bash

source $SCRIPTS/lkd_functions.sh

make mrproper || exit 1

if [[ -f $EXAMPLES/$PROJECT/.config ]]
then
  log "Using costum .config for $PROJECT"
  cp $EXAMPLES/$PROJECT/.config .
  if [[ $# -eq 1 && $1 == "syzkaller" ]]
  then
    log "Building a kernel for syzkaller"
    make kvm_guest.config && \
    cat $FILES/config_syzkaller >> .config || exit 1
  fi
else
  log "Using generic .config"
  make x86_64_defconfig && \
  ./scripts/config \
      -e BPF_EVENTS \
      -e BPF_JIT \
      -e BPF_SYSCALL \
      -e FTRACE_SYSCALLS \
      -e FUNCTION_TRACER \
      -e DYNAMIC_FTRACE \
      -e DEBUG_KERNEL \
      -e DEBUG_INFO \
      -e DEBUG_INFO_DWARF4 \
      -e FRAME_POINTER \
      -e GDB_SCRIPTS \
      -e KALLSYMS \
      -d DEBUG_INFO_BTF \
      -d DEBUG_INFO_DWARF5 \
      -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
      -d DEBUG_INFO_REDUCED \
      -d DEBUG_INFO_COMPRESSED \
      -d DEBUG_INFO_SPLIT \
      -d RANDOMIZE_BASE || exit 1
fi

make -j$(nproc) all && \
make -j$(nproc) modules || exit 1

exit 0
