#!/usr/bin/env bash
# start - control starting and stopping TiddlyWiki via node.js

set -o errexit -o nounset -o pipefail # -o xtrace  # more in common.sh

check_prerequisites() {
    if ! realpath "${BASH_SOURCE[0]}" 2>/dev/null; then # Some macOS versions omitted realpath
        realpath() {
            # this suffices though lacks all the bells and whistles
            command cd -P "$1" && echo "$PWD"
        }
    fi
    # Allow for symlink from repo dir.
    # Assign Default used to allow setting THIS_DIR externally, i.e., for debugging.
    : "${THIS_DIR:="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"}"
    SCRIPT_DIR="$(realpath "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")")"
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/common.sh"
}

config() {
    SLEEPTIME=1
    HELPDESKURL="http://${HOSTNAME}:${PORT}/"
    SESSION=tiddlywiki

    # Note that, despite convention, I use a local installationn of tiddlywiki,
    # not an npm -g (global) package. I avoid things that might interact with other
    # installations and I certainly avoid doing so with `sudo`.
    if [[ -z "${PRE_RELEASE:+unset}" ]]; then
        printf -v START_CMD  \
               "./node_modules/.bin/tiddlywiki '%s' --listen port='%s' host='%s' %s" \
               "$NOTES_DIR" "$PORT" "$HOSTNAME" "${OPTIONS:-}"
    else
        printf -v START_CMD  \
               "cd %s; ./tiddlywiki.js '%s' --listen port='%s' host='%s' %s" \
               "$PRE_RELEASE" "${PWD}/$NOTES_DIR" "$PORT" "$HOSTNAME" "${OPTIONS:-}"
    fi
    # Execute using screen (or tmux) to enable re-connecting to see errors that may be reported.
    # screen is used here because macOS includes it by default.
    printf -v START_CMD "screen -dmS %s; screen -S %s -p 0 -X stuff \"%s\"" \
           "$SESSION" "$SESSION" "${START_CMD}"
    printf -v STOP_CMD "screen -S %s -p 0 -X stuff 'kill^M'" "$SESSION"
    # shellcheck disable=SC2089,2016 # expansion on eval
    printf -v FIND_SCREEN 'screen -ls | awk \"/Detached/ { print \$1; exit 0; }\"'
    # shellcheck disable=SC2090,2016 # expansion on eval
    printf -v ATTACH_CMD 'screen -q -ls || ( [[ %s -ge 8 ]] && screen -rS $(%s) )' \
           '$?' "$FIND_SCREEN"
    if [[ "$VERBOSE" -gt 0 ]]; then
        printf "Generated commands:\nStart: %s\nStop  :%s\nAttach:%s\n" \
               "$START_CMD" "$STOP_CMD" "$ATTACH_CMD"
    fi
    return 0
}

start() {
    # Check if something else already started before starting again
    if ! is_listening "$HOSTNAME" "$PORT"; then
        printf "Running TiddlyWiki via:\n%s\n" "${START_CMD}"
        eval "${START_CMD}"
        sleep "$SLEEPTIME"
    else
        printf "Tiddlywiki is already running, available at %s\n" "$HELPDESKURL"
    fi
    while ! is_listening "$HOSTNAME" "$PORT"; do
        printf "."
        sleep "$SLEEPTIME"
    done
    case "$(uname -s)" in
        (Darwin) open "$HELPDESKURL" ;;
        (Linux)  printf "Running, access at %s\n" "$HELPDESKURL" ;;
    esac
}

stop() {
    if is_listening "$HOSTNAME" "$PORT"; then
        printf "Stopping TiddlyWiki via:\n%s\n" "${STOP_CMD}"
        eval "${STOP_CMD}"
    else
        printf "TiddlyWiki not running on %s:%s\n" "$HOSTNAME" "$PORT"
    fi
}

attach() {
    printf "Attaching to TiddlyWiki via:\n%s\ndetach with ^ad\n" "$ATTACH_CMD"
    sleep $(( SLEEPTIME * 2 ))
    eval "${ATTACH_CMD}"
}

main() {
   check_prerequisites

    if [[ "$VERBOSE" -gt 0 ]]; then
        printf "\nRunning %s\nScript directory is %s\n" "${BASH_SOURCE[0]}" "$SCRIPT_DIR"
        printf "\nNote: Output will report an interrupt due to VERBOSE set to %s\n" "$VERBOSE"
    fi

    command cd "$THIS_DIR" || exit

    config
    #trap "set +x" RETURN && set -x # function debugging
    case "$0" in
        (*start*)
            start
            ;;
        (*stop*)
            stop
            ;;
        (*attach*)
            attach
            ;;
        (*)
            printf "Don't know how to control tiddlywiki with %s\n" "$0"
            ;;
    esac
    exitvalue=$?
    if [[ $exitvalue -ne 0 ]]; then
        exit $exitvalue
    else
        exit "$VERBOSE"
    fi
}

main
