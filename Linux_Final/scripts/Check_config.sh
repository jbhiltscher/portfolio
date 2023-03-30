#!/usr/bin/bash
#set -x
Dir=$1
File=$2

if [ -d "$Dir" ]; then
  ### Take action if $DIR exists ###

    if [ -f "$Dir/$File" ]; then
        echo "$File exists."
    else 
        echo "$Dir/$File does not exist."
        exit 2
    fi

    echo "Okay to Proceed ${Dir} exists and ${File} is in the correct directory"
    exit 0
else
  ###  Control will jump here if $DIR does NOT exists ###
  echo "Error: ${DIR} not found. Can not continue."
  exit 1
fi
