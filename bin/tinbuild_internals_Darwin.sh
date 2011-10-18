#!/usr/bin/env bash

# Do we have timeout? If yes, guard git pull with that - which has a
# tendency to hang forever, when connection is flaky
if which gtimeout > /dev/null 2>&1 ; then
	# MacPorts/self-built - timeout is two hours
	timeout="`which gtimeout` 2h"
fi

do_flock()
{
    if [ "$LOCK" = "1" ] ; then
        if [ ${BIN_DIR?}/flock ] ; then
            [ $V ] && echo "locking..."
            ${BIN_DIR?}/flock $@
        else
            echo "no flock implementation, please build it from buildbot/flock or use -e" 2>&1
            exit 1;
        fi
    fi
}

epoch_from_utc()
{
    date -juf '%Y-%m-%d %H:%M:%S' "$1 $2" '+%s'
}

epoch_to_utc()
{
    date -juf '%s' $1
}

print_date()
{
    date -u '+%Y-%m-%d %H:%M:%S'
}
