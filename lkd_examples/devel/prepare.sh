#!/usr/bin/env bash

useradd -m -s /bin/bash user && \
cp Makefile /home/user && chown user:user /home/user/Makefile && \
cp poc.c /home/user && chown user:user /home/user/poc.c && \
echo "File owned by root!" > /home/user/target_file && \
cd /home/user && \
sudo -u user sh -c 'make all && chmod 777 poc' && \
su user || exit 1
