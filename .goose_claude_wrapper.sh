#!/usr/bin/env bash
"/root/.local/bin/claude" "$@" < /dev/null 2> "/opt/forgenexus/.stderr" &
echo $! > "/opt/forgenexus/.pid"
wait $!
exit $?
