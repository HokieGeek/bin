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

doGrep() { # $1 = case_insensitive, $2 = loadInVim, $@ = expression
    $1 && args+=("--ignore-case")
    args+=(\"${*:3}\")

    if $(git rev-parse --is-inside-working-tree >/dev/null 2>&1); then
        grepprg="git\\ grep\\ --recurse-submodules\\ --line-number\\ --extended-regexp\\ --no-color"
        grepformat="%f:%l:%m"
    elif $(which ag >/dev/null 2>&1); then
        grepprg="ag\\ --nogroup\\ --nocolor\\ --column"
        grepformat="%f:%l:%c:%m"
    elif $(which ack >/dev/null 2>&1); then
        grepprg="ack\\ --nogroup\\ --nocolor\\ --column"
        grepformat="%f:%l:%c:%m"
    else
        grepprg="grep\\ --recursive\\ --line-number\\ --binary-files=without-match\\ --with-filename\\ --extended-regexp"
        grepformat="%f:%l:%m"
        args+=('*')
    fi

    if $2; then
        exec vim -c "set grepprg=${grepprg}" \
                 -c "set grepformat=${grepformat}" \
                 -c "set foldlevel=99" \
                 -c "silent grep ${args[*]}" \
                 -c "if empty(getqflist())|qa|else|if len(getqflist()) > 1|copen|endif|endif"
    else
        eval ${grepprg//\\/} ${args[*]}
    fi
}

doFind() { # $1 = case_insensitive, $2 = loadInVim, $@ = expression
    findCmd='find . -'$($1 && echo "i")'name *'${@:3}'* -print'
    if $2; then
        exec vim -q $(t=$(mktemp); ${findCmd} | xargs file | sed 's/:/:1:/' > $t; echo $t) \
                 -c "set errorformat=%f:%l:%m" \
                 -c "call delete(&errorfile)" \
                 -c "if empty(getqflist())|qa|else|if len(getqflist()) > 1|cwindow|endif|endif"
    else
        exec ${findCmd}
    fi
}

# Parse the arguments
while getopts fiq opt; do
    case $opt in
    f) doSearch="doFind" ;;
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
${doSearch:-"doGrep"} ${caseInsensitive:-false} ${loadInVim:-true} $*
