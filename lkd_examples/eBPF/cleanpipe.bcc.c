#include <linux/fs.h>
#include <linux/pipe_fs_i.h>

extern const struct file_operations pipefifo_fops;

struct data_t {
  u32 pid;
  u64 ts;
  char comm[TASK_COMM_LEN];
};

BPF_RINGBUF_OUTPUT(buffer, 8);

LSM_PROBE(file_permission, struct file *file, int mask)
{
  struct data_t data = {};

  if (file->f_op != (struct file_operations *)PIPEFIFO_FOPS) 
  {
    return 0;
  }

  data.pid = bpf_get_current_pid_tgid();
  data.ts = bpf_ktime_get_ns();
  bpf_get_current_comm(&data.comm, sizeof(data.comm));

  buffer.ringbuf_output(&data, sizeof(data), 0);

  return 0;
}

