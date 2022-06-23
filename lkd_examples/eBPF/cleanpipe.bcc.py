#!/usr/bin/env python3

import time
import sys
from bcc import BPF

def callback(ctx, data, size):
    event = b['buffer'].event(data)
    print("%-16s %10d %10d" % (event.comm.decode('utf-8'), event.pid, event.ts))

def lookup_sym(sym):
    with open("/proc/kallsyms") as syms:
        sym_p = ''
        for line in syms:
            (addr, size, name) = line.rstrip().split(" ", 2)
            name = name.split("\t")[0]
            if name == "pipefifo_fops":
                sym_p = "0x" + addr
                break
        if sym_p == '':
            print(f"ERROR: no {sym} in /proc/kallsyms. Exiting.")
            exit(1)
        return sym_p

with open("cleanpipe.bcc.c", "r") as f:
    text = f.read()
    text = text.replace("PIPEFIFO_FOPS", lookup_sym("pipefifo_fops"))

b = BPF(text=text)
b['buffer'].open_ring_buffer(callback)

print("LSM hook file_permission on pipe operations, ctrl-c to exit.")

print("%-16s %10s %10s %10s" % ("COMM", "PID", "TIME", "PIPE"))

try:
    while 1:
        b.ring_buffer_poll()
        time.sleep(0.5)
except KeyboardInterrupt:
    sys.exit(0)
