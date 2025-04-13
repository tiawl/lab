#! /usr/bin/env bash

source_dir () {
  local file
  for file in sh/container/*
  do
    source "${file}"
  done
}

source_dir

container () {
  case "${1}" in
  ( 'create' ) container_create "${@}" ;;
  ( 'start' ) printf 'TODO\n' ;;
  ( 'stop' ) : ;;
  ( 'remove' ) : ;;
  ( 'up' ) printf 'TODO\n' ;;
  ( 'down' ) : ;;
  ( 'created' ) : ;;
  ( 'running' ) : ;;
  ( * ) return 1 ;;
  esac
}
