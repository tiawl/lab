#! /usr/bin/env bash

runner_exec () {
  shift

  local rainbow
  rainbow=( '21' '27' '33' '39' '45' '51' '50' '49' '48' '47' '46' '82' '118' '154' '190' '226' '220' '214' '208' '202' '196' '197' '198' '199' '200' '201' '165' '129' '93' '57' )

  shuffle rainbow
  readonly rainbow

  local json
  json="${1}"
  if is not file "${json}"
  then
    json="${PWD:-"$(pwd)"}/${json}"
  fi
  if is not file "${json}"
  then
    printf 'Can not find %s\n' "${1}" >&2
    return 1
  fi

  gojq --raw-output --from-file <(printf '%s\n' "${jq[json2bash]}") "${json}" --args "${rainbow[@]}"
}
