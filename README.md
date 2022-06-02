This is a Linux kernel debugging setup derived from [linux-kernel-debuggig](https://github.com/martinclauss/linux-kernel-debugging).

To get an overview of the available functionality run `lkd_run.sh` without any arguments.

## Dependencies
see [linux-kernel-debuggig](https://github.com/martinclauss/linux-kernel-debugging)

## Quick start guide: Examples
This project contains some examples to illustrate CVEs found in the Linux kernel. To explore an example
1. `git clone https://github.com/vobst/lkd-cve && cd lkd-cve`
2. select an example by uncommenting `PROJECT` and `COMMIT` variables in `lkd_run.sh`
3. `./lkd_run.sh setup`
4. get a coffee
5. `./lkd_run.sh run debug`
6. log in as `root` with password `test`
7. `./prepare.sh`
8. `./poc`
9. in another shell `./lkd_run.sh debug` and then `./lkd_run.sh gdb`
