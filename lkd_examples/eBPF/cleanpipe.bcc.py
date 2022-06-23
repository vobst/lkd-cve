#!/usr/bin/env python3

import time
import sys
from bcc import BPF

b = None

def callback(ctx, data, size):
    global b
    event = b['buffer'].event(data)
    print("%-16s %10d %10d %10d" % (event.comm.decode('utf-8'), event.pid, event.ts % 100, event.ok))

def lookup_sym(sym):
    with open("/proc/kallsyms") as syms:
        sym_p = ''
        for line in syms:
            (addr, size, name) = line.rstrip().split(" ", 2)
            name = name.split("\t")[0]
            if name == sym:
                sym_p = "0x" + addr
                break
        if sym_p == '':
            print(f"ERROR: no {sym} in /proc/kallsyms. Exiting.")
            exit(1)
        return sym_p

def get_text():
    with open("cleanpipe.bcc.c", "r") as f:
        text = f.read()
        text = text.replace("PIPEFIFO_FOPS", lookup_sym("pipefifo_fops"))
        text = text.replace("PAGE_CACHE_PIPE_BUF_OPS", lookup_sym("page_cache_pipe_buf_ops"))
    return text

def main():
    global b
    b = BPF(text=get_text())
    b['buffer'].open_ring_buffer(callback)

    print("LSM hook file_permission on pipe write attempts, ctrl-C to exit.")
    print("%-16s %10s %10s %10s" % ("COMM", "PID", "TIME", "EXPLOIT???"))

    try:
        while 1:
            b.ring_buffer_poll()
            time.sleep(0.5)
    except KeyboardInterrupt:
        return 0
    
    return 1

if __name__ == "__main__":
    sys.exit(main())
