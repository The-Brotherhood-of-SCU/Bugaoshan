#!/bin/bash
sleep 3
cp -rf "$1"/* "$2/"
"$2/$(basename "$1" | sed 's/_linux_x64//' | sed 's/.zip//')" &
rm "$0"