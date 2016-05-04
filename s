#!/bin/bash

usage() {
    {
    [ $# -gt 0 ] && echo -e "${1}\n"
    echo "USAGE: `basename $0` [-g|-f] [-q] [-i] <EXPRESSION>"
    more << USAGE_INFO

       -g      [DEFAULT] Greps the contents of all of the files in the directory (recursive)
       -f      Searches for file and directory names (recursive)
       -i      Makes any search case-insensitive
       -q      Quits after performing search instead of starting vim
USAGE_INFO
    } >&2
}

doGrep() {
    glob=""
    if `git rev-parse --is-inside-working-tree >/dev/null 2>&1`; then
        grepprg="git\\ grep\\ -n\\ -E\\ --no-color"
        grepformat="%f:%l:%m"
    elif `which ag >/dev/null 2>&1`; then
        grepprg="ag\\ --nogroup\\ --nocolor\\ --column"
        grepformat="%f:%l:%c:%m"
    elif `which ack >/dev/null 2>&1`; then
        grepprg="ack\\ --nogroup\\ --nocolor\\ --column"
        grepformat="%f:%l:%c:%m"
    else
        grepprg="grep\\ -rnIHE"
        grepformat="%f:%l:%m"
        glob="*"
    fi
    $caseInsensitive && opt_ci="-i" || opt_ci=""

    if $loadInVim; then
        exec vim -c "set grepprg=${grepprg}" \
                 -c "set grepformat=${grepformat}" \
                 -c "set foldlevel=99" \
                 -c "set cursorline" \
                 -c "silent grep ${opt_ci} \"${expression}\" ${glob}" \
                 -c "if empty(getqflist())|qa|else|if len(getqflist()) > 1|copen|endif|endif" \
                 -c "set nocursorline"
    else
        `echo ${grepprg} | sed 's/\\\\//g'` ${opt_ci} ${expression} ${glob}
    fi
}

doFind() {
    $caseInsensitive && opt_ci="i" || opt_ci=""
    set -o noglob
    findCmd="find . -${opt_ci}name "*${expression}*" -print"
    unset noglob

    if $loadInVim; then
        results=`mktemp`
        ${findCmd} | xargs file | sed 's/:/:1:/' > ${results}
        if [ -f "${results}" -a `cat ${results} | wc -l` -gt 0 ]; then
            exec vim -c "cfile ${results}" \
                     -c "set errorformat=%f:%l:%m" \
                     -c "if empty(getqflist())|qa|else|if len(getqflist()) > 1|cwindow|endif|endif" \
                     -c "call delete('${results}')"
        fi
    else
        ${findCmd}
    fi
}

expression=""
searchType="GREP"
caseInsensitive=false
loadInVim=true

# Parse the arguments
while [ $# -gt 0 ]; do
    case $1 in
    -f) searchType="FILES";;
    -g) searchType="GREP";;
    -i) caseInsensitive=true ;;
    -q) loadInVim=false ;;
    *) expression="${expression} $1";;
    esac
    shift
done

expression=`echo $expression | sed -e 's/^\s\*//g' -e 's/\s\*$//g'` # Trim
if [ -z "${expression}" ]; then
    usage "No search expression provided"
    exit 1
fi

## Perform the search
case $searchType in
GREP) doGrep ;;
FILES) doFind ;;
esac
