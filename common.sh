#!/usr/bin/env bash

# If environment does not specify, use the FQDN of `hostname`
HOSTNAME=${HOSTNAME:=$(nslookup "$(hostname)" | awk '/Name:/ { print $2 }')}

# If not defined - Task Scheduler won't - initialize HOME
: "${HOME:=$(grep "$(ps -fp $$ | tail -1 | awk '{print $1}'):" /etc/passwd | awk -F ':' '{print $(NF-1)}')}"

if uname -a | grep -q synology && [[ -r  "${TOOLS_PATH:=/var/packages/DiagnosisTool/target/tool}" ]]; then
    # Synology doesn't include nc command, needs ncat from the Diagnostic Tools
    PATH="${TOOLS_PATH}:${PATH}" && export PATH
fi
if ! ( command -v nc || command -v ncat ) >/dev/null ; then
    printf "Need nc or ncat in PATH (%s) to check accessibility to host:port\n" "$PATH" "$HOSTNAME" "$PORT" 1>&2
    return 2
fi

# Unless already set, directory of script this is originally sourced from
: "${THIS_DIR:="$(realpath "$(dirname "${BASH_SOURCE[ ${#BASH_SOURCE[@]} - 1 ]}")")"}"
# Prefer local overrides to defaults using the semi-standard .env
if [[ -r "${THIS_DIR}"/.env ]]; then
    # shellcheck disable=SC1091
    source "${THIS_DIR}"/.env
else
    printf "Found environment.default definitions that are incomplete as given; see README.\n" && exit
fi

setup_log () {
    # A log having been requested, check its path and start logging to it

    local LOGFILE LOGDIR LOGPATH
    LOGDIR="$(dirname "$1")"
    LOGFILE="$(basename "$1")"

    # Arrange for a log file, with complete path, default in HOME
    if [[ "$LOGDIR" == "." ]]; then
        LOGDIR=${HOME}
    fi
    if [[ ! -w "$LOGDIR" ]]; then
        mkdir -p "$LOGDIR"
    fi
    LOGPATH="${LOGDIR}/${LOGFILE}"
    if touch "$LOGPATH"; then
        printf "Log being generated in %s\n" "$LOGPATH"
    else
        printf "\nWarning: Unable to create %s at %s\n" "$LOGFILE" "$LOGPATH" >&2
    fi

    # Re-direct subsequent output into log
    # From: https://www.linuxjournal.com/content/bash-redirections-using-exec
    if test -t 1; then
        # Stdout is a terminal, combine stdout and stderr and append on log filex .
        exec 1>>"$LOGPATH"
        exec 2>&1
    else
        # Stdout is not a terminal.
        npipe=/tmp/$$.tmp
        # shellcheck disable=SC2064
        trap 'printf "Cleaning up %s generation\n" $LOG; rm -f $npipe' EXIT
        mknod $npipe p
        tee -a <$npipe "$LOGPATH" &
        exec 1>&-
        exec 1>$npipe
    fi
}

if [[ -n "$LOG" ]]; then
    setup_log "$LOG"
fi

is_listening() {
    local HOST=$1
    local PORT=$2
    (
        if [[ "$HOST" == "example.com" ]]; then
            printf "unexpected %s, environment needs to be edited; see README.\n" "$HOST"
            return 3
        fi
        if command -v nc ; then
            nc -z "$HOST" "$PORT" 2>/dev/null
        elif command -v ncat ; then
            ncat -z "$HOST" "$PORT" 2>/dev/null
        else
            return 2
        fi
    ) 1>/dev/null
    return $?
}

# Adapted from https://unix.stackexchange.com/a/529287/13887; with shellcheck mods
## Outputs Front-Mater formatted failures for functions not returning 0
## Use the following line after sourcing this file to set failure trap
##    trap 'failure "LINENO" "BASH_LINENO" "${BASH_COMMAND}" "${?}"' ERR
failure() {
    local -n _lineno="${1:-LINENO}"
    local -n _bash_lineno="${2:-BASH_LINENO}"
    local _last_command="${3:-${BASH_COMMAND}}"
    local _code="${4:-0}"

    ## Workaround for read EOF combo tripping traps
    if ! ((_code)); then
        return "${_code}"
    fi

    local _last_command_height
    _last_command_height="$(wc -l <<<"${_last_command}")"

    local -a _output_array=()
    _output_array+=(
        '---'
        "lines_history: [${_lineno} ${_bash_lineno[*]}]"
        "function_trace: [${FUNCNAME[*]}]"
        "exit_code: ${_code}"
    )

    if [[ "${#BASH_SOURCE[@]}" -gt '1' ]]; then
        _output_array+=('source_trace:')
        for _item in "${BASH_SOURCE[@]}"; do
            _output_array+=("  - ${_item}")
        done
    else
        _output_array+=("source_trace: [${BASH_SOURCE[*]}]")
    fi

    if [[ "${_last_command_height}" -gt '1' ]]; then
        _output_array+=(
            'last_command: ->'
            "${_last_command}"
        )
    else
        _output_array+=("last_command: ${_last_command}")
    fi

    _output_array+=('---')
    printf '%s\n' "${_output_array[@]}" >&2
    exit "${_code}"
}

trap 'failure "LINENO" "BASH_LINENO" "${BASH_COMMAND}" "${?}"' ERR INT

set -o functrace -o errtrace -o errexit -o nounset -o pipefail

[[ "$VERBOSE" -le 2 ]] || set -o xtrace  # in case environment increased
