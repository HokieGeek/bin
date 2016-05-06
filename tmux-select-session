#!/bin/bash

tmux list-session | dmenu -l `tmux list-session | wc -l` -b | awk '{ sub(":", "", $1); print $1 }'
