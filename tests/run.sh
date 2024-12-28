#!/bin/bash

function usage() {
	echo "$0 [parse|tree|fail]"
	echo "parse: can identify that the tokens are correct, but does not build an AST"
	echo "tree: can build an AST"
	echo "fail: tests that purposefully fail"
	exit 1
}
if [[ -z "$1" ]]; then
	usage
fi

if [[ "$1" = "parse" ]]; then
	for x in $(find ./parse -type f); do
		../bin/lang -o _ $x && echo "PASS";
	done
elif [[ "$1" = "tree" ]]; then
	for x in $(find ./tree -type f); do
		../bin/lang -o _ $x && echo "PASS";
	done
elif [[ "$1" = "fail" ]]; then
	for x in $(find ./fail -type f); do
		../bin/lang -o _ $x || echo "PASS";
	done
fi
