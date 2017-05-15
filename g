#!/bin/bash

usage() {
    (( $# > 0 )) && echo -e "$@"
    echo "USAGE: ${0##*/} [-f] [-q] [-i] <EXPRESSION>"
    more << USAGE_INFO
       -f      Searches for file and directory names (recursive)
       -i      Makes any search case-insensitive
       -q      Quits after performing search instead of starting vim
USAGE_INFO
} >&2

# Parse the arguments
while getopts fiq opt; do
    case $opt in
    f) doFind=true ;;
    i) caseInsensitive=true ;;
    q) loadInVim=false ;;
    \?) usage "ERROR: Invalid argument: -$OPTARG" ;;
    esac
done
shift $((OPTIND-1))

(( $# == 0 )) && {
    usage "ERROR: No search expression provided"
    exit 1
}

# Perform the search
if ${doFind:-false}; then
    findCmd='find . -'$(${caseInsensitive} && echo "i")'name *'$*'* -print'
    if ${loadInVim}; then
        vim -q <(${findCmd} | xargs file | sed 's/:/:1:/') \
            -c "if empty(getqflist())|qa|else|if len(getqflist()) > 1|cwindow|endif|endif"
    else
        ${findCmd}
    fi
else
    ${caseInsensitive} && args+=("--ignore-case")
    args+=(\"$*\")

    if $(git rev-parse --is-inside-working-tree >/dev/null 2>&1); then
        grepprg="git\\ grep\\ --recurse-submodules\\ --line-number\\ --extended-regexp\\ --no-color"
    elif agAck=($(command -v ag ack 2>/dev/null)); then
        grepprg="${agAck[0]##*/}\\ --nogroup\\ --nocolor\\ --column"
        grepformat="%f:%l:%c:%m"
    else
        grepprg="grep\\ --recursive\\ --line-number\\ --binary-files=without-match\\ --with-filename\\ --extended-regexp"
        args+=('*')
    fi

    if ${loadInVim}; then
        vim -c "set grepprg=${grepprg}" \
            -c "set grepformat=${grepformat:-"%f:%l:%m"}" \
            -c "set foldlevel=99" \
            -c "silent grep ${args[*]}" \
            -c "if empty(getqflist())|qa|else|if len(getqflist()) > 1|copen|endif|endif"
    else
        eval ${grepprg//\\/} ${args[*]}
    fi
fi
