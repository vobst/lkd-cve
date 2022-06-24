int lsm__file_permission(long long unsigned int * ctx):
; LSM_PROBE(file_permission, struct file *file, int mask)
   0: (79) r2 = *(u64 *)(r1 +8)
   1: (79) r6 = *(u64 *)(r1 +0)
   2: (b7) r0 = 0
; struct data_t data = {};
   3: (7b) *(u64 *)(r10 -8) = r0
   4: (7b) *(u64 *)(r10 -16) = r0
   5: (7b) *(u64 *)(r10 -24) = r0
   6: (7b) *(u64 *)(r10 -32) = r0
   7: (7b) *(u64 *)(r10 -40) = r0
; if (file->f_op != (struct file_operations *)0xffffffff825c83a0
   8: (79) r1 = *(u64 *)(r6 +40)
; || mask == MAY_READ) 
   9: (55) if r1 != 0x825c83a0 goto pc+69
  10: (67) r2 <<= 32
  11: (77) r2 >>= 32
  12: (15) if r2 == 0x4 goto pc+66
; data.pid = bpf_get_current_pid_tgid();
  13: (85) call bpf_get_current_pid_tgid#158096
; data.pid = bpf_get_current_pid_tgid();
  14: (63) *(u32 *)(r10 -40) = r0
; data.ts = bpf_ktime_get_ns();
  15: (85) call bpf_ktime_get_ns#158352
; data.ts = bpf_ktime_get_ns();
  16: (7b) *(u64 *)(r10 -32) = r0
; bpf_get_current_comm(&data.comm, sizeof(data.comm));
  17: (bf) r1 = r10
  18: (07) r1 += -23
; bpf_get_current_comm(&data.comm, sizeof(data.comm));
  19: (b7) r2 = 16
  20: (85) call bpf_get_current_comm#158496
  21: (b7) r1 = 0
; data.ok = 0;
  22: (73) *(u8 *)(r10 -24) = r1
; pipe = (struct pipe_inode_info *)file->private_data;
  23: (79) r6 = *(u64 *)(r6 +200)
  24: (bf) r1 = r10
; data.pid = bpf_get_current_pid_tgid();
  25: (07) r1 += -72
; bpf_probe_read_kernel(&ring_size, sizeof(u32), &pipe->ring_size);
  26: (bf) r3 = r6
  27: (07) r3 += 92
; bpf_probe_read_kernel(&ring_size, sizeof(u32), &pipe->ring_size);
  28: (b7) r2 = 4
  29: (85) call bpf_probe_read_kernel#-62144
  30: (bf) r1 = r10
; data.pid = bpf_get_current_pid_tgid();
  31: (07) r1 += -68
; bpf_probe_read_kernel(&head, sizeof(u32), &pipe->head);
  32: (bf) r3 = r6
  33: (07) r3 += 80
; bpf_probe_read_kernel(&head, sizeof(u32), &pipe->head);
  34: (b7) r2 = 4
  35: (85) call bpf_probe_read_kernel#-62144
; pipe_mask = ring_size - 1;
  36: (61) r7 = *(u32 *)(r10 -72)
; bpf_probe_read_kernel(&buf, sizeof(u64), &pipe->bufs);
  37: (07) r6 += 152
  38: (bf) r1 = r10
; data.pid = bpf_get_current_pid_tgid();
  39: (07) r1 += -48
; bpf_probe_read_kernel(&buf, sizeof(u64), &pipe->bufs);
  40: (b7) r2 = 8
  41: (bf) r3 = r6
  42: (85) call bpf_probe_read_kernel#-62144
; pipe_mask = ring_size - 1;
  43: (07) r7 += -1
; buf = buf + ((head-1) & pipe_mask);
  44: (61) r1 = *(u32 *)(r10 -68)
; buf = buf + ((head-1) & pipe_mask);
  45: (07) r1 += -1
; buf = buf + ((head-1) & pipe_mask);
  46: (5f) r1 &= r7
; buf = buf + ((head-1) & pipe_mask);
  47: (67) r1 <<= 32
  48: (77) r1 >>= 32
  49: (27) r1 *= 40
; buf = buf + ((head-1) & pipe_mask);
  50: (79) r3 = *(u64 *)(r10 -48)
; buf = buf + ((head-1) & pipe_mask);
  51: (0f) r3 += r1
; buf = buf + ((head-1) & pipe_mask);
  52: (7b) *(u64 *)(r10 -48) = r3
; bpf_probe_read_kernel(&flags, sizeof(u64), &buf->flags);
  53: (07) r3 += 24
  54: (bf) r1 = r10
; data.pid = bpf_get_current_pid_tgid();
  55: (07) r1 += -64
; bpf_probe_read_kernel(&flags, sizeof(u64), &buf->flags);
  56: (b7) r2 = 8
  57: (85) call bpf_probe_read_kernel#-62144
; bpf_probe_read_kernel(&ops, sizeof(u64), &buf->ops);
  58: (79) r3 = *(u64 *)(r10 -48)
; bpf_probe_read_kernel(&ops, sizeof(u64), &buf->ops);
  59: (07) r3 += 16
  60: (bf) r1 = r10
; data.pid = bpf_get_current_pid_tgid();
  61: (07) r1 += -56
; bpf_probe_read_kernel(&ops, sizeof(u64), &buf->ops);
  62: (b7) r2 = 8
  63: (85) call bpf_probe_read_kernel#-62144
; if (flags & PIPE_BUF_FLAG_CAN_MERGE && ops == (struct pipe_buf_operations *)0xffffffff825c9920)
  64: (79) r1 = *(u64 *)(r10 -64)
; if (flags & PIPE_BUF_FLAG_CAN_MERGE && ops == (struct pipe_buf_operations *)0xffffffff825c9920)
  65: (57) r1 &= 16
; if (flags & PIPE_BUF_FLAG_CAN_MERGE && ops == (struct pipe_buf_operations *)0xffffffff825c9920)
  66: (15) if r1 == 0x0 goto pc+11
  67: (79) r1 = *(u64 *)(r10 -56)
  68: (55) if r1 != 0x825c9920 goto pc+9
  69: (b7) r1 = 1
; data.ok = 1;
  70: (73) *(u8 *)(r10 -24) = r1
; bpf_ringbuf_output(bpf_pseudo_fd(1, -1), &data, sizeof(data), 0);
  71: (18) r1 = map[id:14]
  73: (bf) r2 = r10
; data.ok = 1;
  74: (07) r2 += -40
; bpf_ringbuf_output(bpf_pseudo_fd(1, -1), &data, sizeof(data), 0);
  75: (b7) r3 = 40
  76: (b7) r4 = 0
  77: (85) call bpf_ringbuf_output#210336
; return data.ok;
  78: (71) r0 = *(u8 *)(r10 -24)
; LSM_PROBE(file_permission, struct file *file, int mask)
  79: (95) exit
