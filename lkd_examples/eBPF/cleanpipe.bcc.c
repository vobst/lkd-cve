#include <linux/fs.h>
#include <linux/pipe_fs_i.h>

extern const struct file_operations pipefifo_fops;

struct data_t {
  u32 pid;
  u64 ts;
  u8 ok;
  char comm[TASK_COMM_LEN];
};

BPF_RINGBUF_OUTPUT(buffer, 8);

LSM_PROBE(file_permission, struct file *file, int mask)
{
  struct data_t data = {};
  struct pipe_inode_info *pipe;
  struct pipe_buffer *buf;
  struct pipe_buf_operations *ops;
  u64 flags;
  u32 pipe_mask, head, ring_size;

  if (file->f_op != (struct file_operations *)PIPEFIFO_FOPS
		  || mask == MAY_READ) 
  {
    return 0;
  }

  data.pid = bpf_get_current_pid_tgid();
  data.ts = bpf_ktime_get_ns();
  bpf_get_current_comm(&data.comm, sizeof(data.comm));
  data.ok = 0;

  pipe = (struct pipe_inode_info *)file->private_data;
  bpf_probe_read_kernel(&ring_size, sizeof(u32), &pipe->ring_size);
  bpf_probe_read_kernel(&head, sizeof(u32), &pipe->head);
  pipe_mask = ring_size - 1;

  bpf_probe_read_kernel(&buf, sizeof(u64), &pipe->bufs);
  buf = buf + ((head-1) & pipe_mask);

  bpf_probe_read_kernel(&flags, sizeof(u64), &buf->flags);
  bpf_probe_read_kernel(&ops, sizeof(u64), &buf->ops);

  if (flags & PIPE_BUF_FLAG_CAN_MERGE && ops == (struct pipe_buf_operations *)PAGE_CACHE_PIPE_BUF_OPS)
  { 
    data.ok = 1;
    buffer.ringbuf_output(&data, sizeof(data), 0);
  }

  return data.ok;
}

