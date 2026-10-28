#!/bin/bash
# macOS: double-click in Finder to install tools, build and flash.
cd "$(dirname "$0")" || exit 1
./tools/flash.sh "$@"
status=$?
echo
read -r -p "Press Enter to close this window " _
exit $status
