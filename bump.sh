#!/bin/sh
# Stamp a new build id so open copies of Lifeloop refresh themselves.
b=$(date -u +%Y%m%d-%H%M%S)
sed -i "s/<meta name=\"build\" content=\"[^\"]*\">/<meta name=\"build\" content=\"$b\">/" index.html
echo "$b"
