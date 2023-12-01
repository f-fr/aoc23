#!/bin/bash

pth=$(dirname -- "$0")
day=$(printf "%02d" "$1")
pushd $pth >& /dev/null

SESSIONCOOKIE=$(cat .session)

mkdir "src/$day"
cp -i "src/template_main.zig" "src/$day/main.zig"
sed -i -e "s/DAY/$day/" "src/$day/main.zig"
hg add "src/$day/main.zig"

mkdir -p "input/$day"
curl "https://adventofcode.com/2023/day/$1/input" --compressed -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0' -H "Cookie: session=$SESSIONCOOKIE" > input/$day/input1.txt
hg add input/$day/input1.txt

popd >& /dev/null
