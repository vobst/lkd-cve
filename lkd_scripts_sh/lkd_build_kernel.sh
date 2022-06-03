#!/usr/bin/env bash

make mrproper && \
make x86_64_defconfig && \
make kvm_guest.config && \
./scripts/config \
    -e CONFIG_USER_NS \
    -m CONFIG_NF_TABLES \
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
    -d RANDOMIZE_BASE && \
make -j$(nproc) all && \
make -j$(nproc) modules 
