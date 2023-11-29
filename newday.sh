#!/bin/bash

pth=$(dirname -- "$0")
day=$(printf "%02d" "$1")
pushd $pth >& /dev/null
mkdir "src/$day"
mkdir "input/$day"
cp -i "src/template_main.zig" "src/$day/main.zig"
sed -i -e "s/DAY/$day/" "src/$day/main.zig"
hg add "src/$day/main.zig"
popd >& /dev/null
