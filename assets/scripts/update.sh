#!/bin/bash
sleep 3
cp -rf "$1"/* "$2/"
"{EXE_PATH}" &
rm "$0"