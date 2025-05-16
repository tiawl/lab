#! /usr/bin/env bash

runner_exec () { #HELP <yaml_file> [<arg1> <args2> ...]|Execute the runner described by the <yaml_file>. Optional arguments are used by the executed runner
  shift

  local script
  script="$(runner dry "${1}")"
  readonly script

  shift

  env --ignore-environment BASH="${BASH:-}" bash --norc --noprofile -s -c "${script}" -- "${@}"
}
