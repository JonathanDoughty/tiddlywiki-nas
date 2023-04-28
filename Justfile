#!/usr/bin/env just --justfile
# tiddlywiki-nas content manipulation via `just` (https://github.com/casey/just)

home_dir := env_var('HOME')
# Where I keep the GitHib mirror locally
LOCAL_PUBLIC := home_dir + "/CM/Public/tiddywiki-nas"
GITHUB := "git@github.com:JonathanDoughty/tiddlywiki-nas.git"

# List these targets
default:
    @just --list --unsorted

# Export the current HEAD to public mirror
export:
    git archive HEAD | (cd {{LOCAL_PUBLIC}}; tar xf -)

# Push current repo to githup
push:
    git push origin main
