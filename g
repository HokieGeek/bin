#!/bin/bash

usage() {
    (( $# > 0 )) && echo -e "$@"
    echo "USAGE: ${0##*/} [-f] [-q] [-i] <EXPRESSION>"
    echo "   -f      Recursively searches for file and directory names instead of the contents"
    echo "   -i      Makes any search case-insensitive"
    echo "   -q      Quits after performing search instead of starting vim"
} >&2

while getopts :fiq opt; do
    case $opt in
    f) doFind=true ;;
    i) caseInsensitive=true ;;
    q) quick=true ;;
    \?) usage "ERROR: Invalid argument: -$OPTARG"; exit 1 ;;
    esac
done
shift $((OPTIND-1))

: ${@?$(usage "ERROR: No search expression provided")}

if ${doFind:-false}; then
    findCmd="find . -${caseInsensitive:+i}name *${*}*"
    if ${quick:-false}; then
        ${findCmd}
    else
        vim --cmd "set errorformat=%f:%m" \
            -q <(${findCmd} -printf "%p:%TY-%Tm-%Td %TH%TM %kKb %u:%g %m\n") \
            -c "if empty(getqflist())|qa|else|if len(getqflist()) > 1|copen|set nolist|endif|endif"
    fi
else
    if git rev-parse --is-inside-working-tree >/dev/null 2>&1; then
        command -v git-grep-recursive 2>/dev/null 2>&1 \
            && grepprg="git-grep-recursive" \
            || grepprg="git\\ grep\\ --recurse-submodules"
        grepprg+="\\ --line-number\\ --extended-regexp\\ --no-color"
    elif agAck=($(command -v ag ack 2>/dev/null)); then
        grepprg="${agAck[0]}\\ --nogroup\\ --nocolor\\ --column"
        grepformat="%f:%l:%c:%m"
    else
        grepprg="grep\\ --recursive\\ --line-number\\ --extended-regexp\\ --binary-files=without-match\\ --with-filename"
        set -- \"$@\" '*'
    fi
    ${caseInsensitive:-false} && grepprg+="\\ --ignore-case"

    if ${quick:-false}; then
        eval ${grepprg//\\/} "$*"
    else
        vim -c "set foldlevel=99" \
            -c "set grepprg=${grepprg}" \
            -c "set grepformat=${grepformat:-"%f:%l:%m"}" \
            -c "silent grep $*" \
            -c "if empty(getqflist())|qa|else|if len(getqflist()) > 1|copen|endif|endif"
    fi
fi
