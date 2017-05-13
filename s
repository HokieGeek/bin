#!/bin/bash

usage() {
    (( $# > 0 )) && echo -e "$@"
    echo "USAGE: ${0##*/} [-g|-f] [-q] [-i] <EXPRESSION>"
    more << USAGE_INFO
       -g      [DEFAULT] Greps the contents of all of the files in the directory (recursive)
       -f      Searches for file and directory names (recursive)
       -i      Makes any search case-insensitive
       -q      Quits after performing search instead of starting vim
USAGE_INFO
} >&2

doGrep() { # $1 = case_insensitive, $2 = loadInVim, $@ = expression
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
        glob="*"
    fi
    $1 && opt_ci="--ignore-case"

    if $2; then
        exec vim -c "set grepprg=${grepprg}" \
                 -c "set grepformat=${grepformat}" \
                 -c "set foldlevel=99" \
                 -c "set cursorline" \
                 -c "silent grep ${opt_ci} \"${@:3}\" ${glob}" \
                 -c "if empty(getqflist())|qa|else|if len(getqflist()) > 1|copen|endif|endif" \
                 -c "set nocursorline"
    else
        ${grepprg//\\/} ${opt_ci} ${@:3} ${glob}
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
while (( $# > 0 )); do
    case $1 in
    -f) doSearch="doFind" ;;
    -g) doSearch="doGrep" ;;
    -i) caseInsensitive=true ;;
    -q) loadInVim=false ;;
    *) expression+=("$1") ;;
    esac
    shift
done
(( ${#expression[@]} == 0 )) && {
    usage "ERROR: No search expression provided"
    exit 1
}

## Perform the search
${doSearch:-"doGrep"} ${caseInsensitive:-false} ${loadInVim:-true} ${expression[*]}
