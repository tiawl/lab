#! /usr/bin/env bash

shebangless () {
  sed '/^#\s*!/{:loop;N;s/.*\n$//;t loop;s/^\n\+//}' "${@}"
}

# executed by setup.sh
compile () {
  on errexit inherit_errexit errtrace functrace noclobber nounset pipefail lastpipe extglob checkwinsize

  # (:;:) is a micro sleep to ensure the variables are exported immediately.
  (:;:)

  harden base64
  harden cat
  harden git
  harden mkdir
  harden rm
  harden sed

  local name version help
  name='navy'
  version="$(git -C "${SDIR}" describe --match *.*.* --tags --abbrev=9)"
  version="${version%-*}"
  version="${version%\.*}.${version#*-}"
  help="$(on globstar
    find_max_size () {
      cols=
      if ge "${#entry}" "${COLUMNS}"
      then
        cols="$(( ${COLUMNS} - 1 ))"
        while str not eq "${entry:${cols}:1}" ' '; do (( cols-=1 )); done
        (( cols+=1 ))
      fi
    }
    declare -a lines
    max_width='0'
    for src in "${SDIR}/src"/**/*
    do
      if is file "${src}"
      then
        line="$(sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_]*\)\s*()\s*{\s*#HELP/\1/p' "${src}" | sed ':loop; s/^\([^[:space:]_]\+\)_/\1 /; t loop')"
        if str not empty "${line:-}"
        then
          lines+=( "${line}" )
        fi
      fi
    done
    for line in "${lines[@]}"
    do
      mapfile -t -d '|' split <<< "${line}"
      max_width="$(( ${#split[0]} > ${max_width} ? ${#split[0]} : ${max_width} ))"
    done
    for line in "${lines[@]}"
    do
      mapfile -t -d '|' split <<< "${line}"
      printf -v entry -- "        %-${max_width}s %s" "${split[0]}" "${split[1]%$'\n'}"
      find_max_size
      printf '%s\\n' "${entry:0:${cols:-"${COLUMNS}"}}"
      entry="${entry:${cols:-"${COLUMNS}"}}"
      while gt "${#entry}" '0'
      do
        find_max_size
        printf "        %${max_width}s %s\\n" '' "${entry:0:${cols:-"${COLUMNS}"}}"
        entry="${entry:${cols:-"${COLUMNS}"}}"
      done
    done
  )"
  readonly name version help

  rm -rf "${SDIR}/bin"
  mkdir -p "${SDIR}/bin"
  off noclobber
  cat <<EOF > "${SDIR}/bin/${name}"
#! /usr/bin/env bash

$(on globstar
  for src in "${SDIR}/src"/**/*
  do
    if is file "${src}"
    then
      sed 's/.*#SKIP$//g' "${src}" | shebangless
      printf '\n'
    fi
  done)

version () {
  printf '${name} ${version}\n' >&2
}

help () {
  version
  printf '\nCOMMANDS:\n${help}\n' >&2
}

load_resources () {
  global -A sed jq buf
$(on globstar
  for dir in sed jq
  do
    for entry in "${SDIR}/${dir}"/**/*
    do
      if is file "${entry}"
      then
        printf '  %s[%s]=%s\n' "${dir}" "$(basename "${entry}" ".${dir}")" "'$(shebangless "${entry}" | sed "s/'/'\"'\"'/g")'"
      fi
    done
  done
  for entry in "${SDIR}/buf/vendor"/**/*
  do
    if is file "${SDIR}/buf/descriptor_sets/$(basename "${entry}")"
    then
      printf '  buf[descriptor_set_%s]=%s\n' "$(basename "${entry}" '.proto')" "'$(base64 --wrap 0 "${SDIR}/buf/descriptor_sets/$(basename "${entry}")")'"
      printf '  buf[vendor_%s]=%s\n' "$(basename "${entry}" '.proto')" "'$(sed "s/'/'\"'\"'/g" "${entry}")'"
    fi
  done)
  readonly sed jq buf
}

${name} () {
  if is not var '${name^^}_REEXEC_WITH_EMPTY_ENV'
  then
    \\command exec -c env --ignore-environment BASH="\${BASH:-}" ${name^^}_REEXEC_WITH_EMPTY_ENV='yes' bash --norc --noprofile "\${BASH_SOURCE[0]}" "\${@}" || \\command exit 1
  fi

  on errexit inherit_errexit errtrace functrace noclobber nounset pipefail lastpipe extglob

  bash_setup

  load_resources

  orchestrator "\${@}"
}

${name} "\${@}"
EOF
  chmod 0700 "${SDIR}/bin/${name}"
}

compile "${@}"
