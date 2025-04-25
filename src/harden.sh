#! /usr/bin/env bash

# 1) fail if no external tool exists with the specified name
# 2) wrap the external tool as a function
harden () {
  local dir flag

  IFS=':'
  set -f
  for dir in ${PATH}
  do
    if can exec "${dir}/${1}"
    then
      eval "${1//-/_} () { ${dir}/${1} \"\${@}\"; }"
      flag='true'
      break
    fi
  done
  set +f
  IFS="${old_ifs}"

  if str not eq "${flag:-}" 'true'
  then
    printf 'This script needs "%s" but can not find it\n' "${1}" >&2
    return 1
  fi
}
