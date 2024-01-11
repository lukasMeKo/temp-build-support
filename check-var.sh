#!/usr/bin/env bash

# prints all variables which are not present and exits with non zero when any
# were not present
FAILED=
for VAR in $@; do
	if ! printenv $VAR >/dev/null; then
		printf "\e[31mvariable not set:\e[0m %s\n" "${VAR}" >/dev/stderr
		FAILED=1
	fi
done
test -z $FAILED
