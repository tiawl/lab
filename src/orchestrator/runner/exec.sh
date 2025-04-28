#! /usr/bin/env bash

runner_exec () { #HELP <yaml_file> [arg1 args2 ...]\t\t\t\t\tExecute the runner described by the <yaml_file>\n\t\t\t\t\t\t\t\t\t\t\tOptional arguments are used by the executed runner
  shift

  local yml
  yml="${1}"
  readonly yml

  shift

  runner dry "${yml}" | bash --norc --noprofile -s -- "${@}"
}
