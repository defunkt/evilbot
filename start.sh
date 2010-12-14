#!/bin/sh
# poor man's reloader.
# re-starts conavore when it dies of an error.

until /usr/bin/env coffee conavore.coffee; do
    echo "conavore crashed with exit code $?. respawning.." >&2
    sleep 1
done
