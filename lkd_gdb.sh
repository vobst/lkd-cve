#!/usr/bin/env bash

gdb \
-q \
-x lkd_${PROJECTE}_files/lkd_${PROJECTE}_gdb.py
