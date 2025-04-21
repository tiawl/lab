#! /usr/bin/env bash

source_client () {
  source sh/urlencode.sh

  local file

  shopt -s globstar
  for file in sh/client/**/*.sh
  do
    source "${file}"
  done
  shopt -u globstar
}

source_client
