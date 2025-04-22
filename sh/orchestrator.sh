#! /usr/bin/env bash

source_orchestrator () {
  source sh/urlencode.sh

  local file

  shopt -s globstar
  for file in sh/orchestrator/**/*.sh
  do
    source "${file}"
  done
  shopt -u globstar
}

source_orchestrator
