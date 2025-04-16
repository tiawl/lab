#! /usr/bin/env bash

urlencode () {
  declare -A encoded
  encoded['{']='%7B'
  encoded['}']='%7D'
  encoded[':']='%3A'
  encoded['"']='%22'
  encoded['/']='%2F'
  encoded['?']='%3F'
  encoded['&']='%26'
  encoded['=']='%3D'
  encoded['.']='%2E'

  local str char
  str="${1}"
  set -f
  for char in ${!encoded[@]}
  do
    str="${str//"${char}"/"${encoded["${char}"]}"}"
  done
  set +f
  printf '%s\n' "${str}"
}
