#!/bin/sh
# poor man's reloader.
# re-starts evilbot when he dies of an error.

until /usr/bin/env coffee evilbot.coffee; do
    echo "evilbot crashed with exit code $?. respawning.." >&2
    sleep 1
done
