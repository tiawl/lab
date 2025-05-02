#! /usr/bin/env bash

runner_dry () { #HELP <yaml_file>\t\t\t\t\t\t\tDisplay the runner bash script without executing it
  shift

  local rainbow
  rainbow=( '21' '27' '33' '39' '45' '51' '50' '49' '48' '47' '46' '82' '118' '154' '190' '226' '220' '214' '208' '202' '196' '197' '198' '199' '200' '201' '165' '129' '93' '57' )

  shuffle rainbow
  readonly rainbow

  local yml
  yml="${1}"
  if is not file "${yml}"
  then
    yml="${PWD:-"$(pwd)"}/${yml}"
  fi
  if is not file "${yml}"
  then
    printf 'Can not find %s\n' "${1}" >&2
    return 1
  fi

  gojq --yaml-input --raw-output --from-file <(printf '%s\n' "${jq[yml2bash]}") "${yml}" --args "${rainbow[@]}" --arg env "$(
  set -f
  for func in init load_ressources bash_setup \
    $(compgen -A function -X '!(container*|image*|volume*|network*|runner*)') \
    urlencode \
    not eq gt lt ge le can is has str global \
    basename dirname \
    on off capture \
    defer harden \
    shuffle
    do
      declare -f "${func}"
      printf '\n'
    done
  )"
}
