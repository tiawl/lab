#! /usr/bin/env bash

main () {
  if [[ -d ~/.bash_profile.d ]]
  then
    local file
    for file in ~/.bash_profile.d/*.sh
    do
      if [[ -r "${file}" ]]
      then
        source "${file}"
      fi
    done
  fi
}

main
