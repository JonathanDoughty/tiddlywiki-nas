#!/usr/bin/env bash
# daily - orchestrate committing & backing up local git controlled content

prerequisites() {
    set -o errexit -o nounset                           # more in common.sh

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

script_info() {
    if [[ "$VERBOSE" -gt 0 ]]; then
        printf "\nRunning %s\nScript directory is %s\n" "${BASH_SOURCE[0]}" "$SCRIPT_DIR"
        printf "\nNote: Output will report an interrupt due to VERBOSE set to %s\n" "$VERBOSE"
        printf "\ngit repo at %s\ngit remote on %s\n" "$PWD" "$ORIGIN"
        printf "Backup archive will be copied to %s\n" "$OFFSITE"
        if [[ "$VERBOSE" -gt 1 ]]; then  # Provide details about environment and repo
            printf "PATH=%s\n" "$PATH"
            printf "Running as user %s in %s\n" "$(id -un)" "$PWD"
            printf "Current git branch is %s\n" "$(git branch --show-current)"
            printf "Recent git log entries:\n"
            git log --graph --no-merges --pretty=format:'%w(0,0,10)%h -%d %s% b (%cr)' --max-count=5
            printf "submodule status:\n"
            git submodule status
        fi
    fi
}

commit() {
    # Any notable changes - modifications or un-ignored additions?
    if [ "$(git status --porcelain | grep -c -E '^.?[?ADMR]')" -gt 0 ]; then
      msg="$(hostname) updates for $(date +'%Y/%m/%d')"
      git ls-files -mz | xargs -0 git add  # stage the modifications
      if [ "$(git status --porcelain | grep -c -E '^.?[?]')" -gt 0 ]; then
          # stage new (un-ignored) files, e.g., tiddlers - other than Draft's
          git ls-files -z --others --exclude-standard | grep -vze '/Draft.of.' | xargs -0 git add
      fi
      git commit -q -m "$msg"
      printf "Commited %s\n" "$msg"
    # Or, is a leftover archive still around?
    elif [ -e "${ARCHIVE}" ]; then
      printf "Unsynced archived %s exists, retry backup\n" "${ARCHIVE}"
    else
      printf "No changes to commit\n"
      git status --short
      return 1  # fail this recipe so remaining steps are skipped
    fi
}

push() {
    # Assumes local git repo has defined upstream branch
    # e.g., `git push --set-upstream [origin] [localbranch]`
    if nslookup "${OFFSITE}" &>/dev/null && [[ "${OFFSITE}" != "example.com" ]]; then
        git pull origin         # integrate updates from remote first
        git push origin "$(git rev-parse --abbrev-ref HEAD)"
    else
        printf "%s not accessible, git commits not pushed\n" "${OFFSITE}"
    fi
}

offsite () {
    git archive --format=zip --output="${ARCHIVE}" HEAD
    # ssh accessible on off site?
    if is_listening "${OFFSITE}" "${SSH_PORT}" ; then
        # This assumes the local user has ssh access, perhaps via ~/.ssh/config, to OFFSITE
        rsync -rsh -azq --rsh="ssh -p${SSH_PORT}" "${ARCHIVE}" "${OFFSITE}":
        printf "%s rsynced to %s for %s\n" "${ARCHIVE}" "${OFFSITE}" "$(date +'%d %B')"
        rm "${ARCHIVE}"
    else
        printf "%s not accessible, %s not rsynced\n" "${OFFSITE}" "${ARCHIVE}"
        # If the offsite copy failed leave the archive as a signal to retry
        exit $?
    fi
}

backup() {
    push || return $?
    offsite || return $?
}

process_status() {
    local PID=$$
    # shellcheck disable=SC2009 # use commands native to vanilla DSM
    if ps -ef | grep -v "$PID" | grep "$PROCESS" 1>/dev/null ; then
       printf "%s running.\n" "$PROCESS"
    else
       printf "%s is not running\n" "$PROCESS"
    fi
}

daily() {
    prerequisites

    cd "$THIS_DIR" || exit
    script_info
    commit || return $?
    backup || return $?
    process_status
    [[ ( "$?" || "$VERBOSE" ) ]] # if VERBOSE>0 signal Task Scheduler to produce output
}

daily
