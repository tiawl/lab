#! /usr/bin/env bash

tests () {
  set -C -e -u -o pipefail
  shopt -s lastpipe extglob

  sdir="$(CDPATH='' cd -- "$(dirname -- "${0}")" > /dev/null 2>&1; pwd)"
  readonly sdir

  local verbose xtrace
  local -a opts

  while [[ "${#}" -gt 0 ]]
  do
    case "${1}" in
    # Handle '-abc' the same as '-a -bc' for short-form no-arg options
    ( -[xv]?* ) set -- "${1%"${1#??}"}" "-${1#??}" "${@:2}"; continue ;;
    ( -x ) xtrace=true ;;
    ( -v ) verbose=true ;;
    ( * ) printf 'Unknown option: "%s"\n' "${1}"; return 1 ;;
    esac
    shift
  done

  if [[ -v xtrace ]]
  then
    opts+=( '--trace' )
    verbose=true
  fi

  if [[ -v verbose ]]
  then
    opts+=( '--verbose-run' '--timing' '--show-output-of-passing-tests' '--print-output-on-failure' )
  fi

  shopt -s globstar
  #bats --filter '\[return 1\] nested defers' "${opts[@]}" "${sdir}"/bats/**/*.bats
  bats --formatter "${sdir}/bats/formatter.sh" "${opts[@]}" "${sdir}"/bats/**/*.bats
}

tests "${@}"
