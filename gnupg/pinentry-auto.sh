#!/bin/sh

platform="$(uname -s)"

if [ "${platform}" = "Darwin" ]; then
    exec "${HOMEBREW_PREFIX}/bin/pinentry-curses"

elif [ "${platform}" = "Linux" ]; then
    exec "/usr/bin/pinentry-curses"

else
    printf "Unable to start pinentry for platform '%s'.\n" "${platform}" >&2
    exit 1

fi
