#!/bin/sh

if [ $# -gt 0 ]; then
    xterminal="$1"
else
    for xt in st urxvtc urxvt gnome-terminal xterm; do
        which ${xt} &>/dev/null && {
            xterminal="${xt}"
            break
        }
    done
fi

for s in $(tmux list-sessions | awk '$NF !~ /attached/ { sub(":", "", $1); print $1 }'); do
    ${xterminal} -e tmux attach-session -t $s &>/dev/null &
done
disown -a
