This is a Linux kernel debugging setup derived from [linux-kernel-debuggig](https://github.com/martinclauss/linux-kernel-debugging).

To get an overview of the available functionality run `lkd_run.sh` without any arguments.

## Dependencies
See [linux-kernel-debuggig](https://github.com/martinclauss/linux-kernel-debugging](https://github.com/martinclauss/linux-kernel-debugging#requirements) for a list of dependencies.

## Quick start guide: Examples
This project contains some examples to kickstart exploration of some CVEs found in the Linux kernel. To explore an example:
1. `git clone https://github.com/vobst/lkd-cve && cd lkd-cve`
2. select an example by uncommenting the corresponding `PROJECT` and `COMMIT` variables in `lkd_run.sh`
3. adjust the other variables to your system
4. `./lkd_run.sh setup`
5. get a coffee ☕ :)
6. `./lkd_run.sh run debug`
7. log in as `root` with password `test`
8. `./prepare.sh`
9. `./poc`
10. in another shell `./lkd_run.sh debug` and then `./lkd_run.sh gdb`

## Scripts
There are some python scripts in `lkd_scripts_gdb/lkd/` that aim to enhance the kernel debugging experience. Feel free to check them out and import them into your own scripts.

## Other branches
There are probably some other branches that possibly contain features not available on `master` e.g., scripts for heap functionality. Check them out before implementing something yourself :)
