#! /usr/bin/env bash

shebangless () {
  sed '/^#\s*!/{:loop;N;s/.*\n$//;t loop;s/^\n\+//}' "${@}"
}

# executed by setup.sh
compile () {
  on errexit inherit_errexit errtrace functrace noclobber nounset pipefail lastpipe extglob

  harden base64
  harden cat
  harden git
  harden mkdir
  harden rm
  harden sed

  local name version len_cmd src desc
  local -a help split
  name='murloc'
  version="$(git -C "${SDIR}" describe --match *.*.* --tags --abbrev=9)"
  version="${version%-*}"
  version="${version%\.*}.${version#*-}"

  on globstar
  for src in "${SDIR}/src"/**/*
  do
    if is file "${src}"
    then
      desc="$(sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_]*\)\s*()\s*{\s*#HELP/\1/p' "${src}" | sed ':loop; s/^\([ a-z]\+\)_/\1 /; t loop')"
      if str not empty "${desc:-}"
      then
        help+=( "${desc}" )
      fi
    fi
  done
  off globstar

  len_cmd='0'
  for desc in "${help[@]}"
  do
    mapfile -t -d '|' split <<< "${desc}"
    len_cmd="$(( ${#split[0]} > ${len_cmd} ? ${#split[0]} : ${len_cmd} ))"
  done

  readonly name version help len_cmd

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
  cut_line () {
    local cols
    cols="\${COLUMNS}"
    if ge "\${#1}" "\${COLUMNS}"
    then
      set -- "\${1}" "\${1:0:\${COLUMNS}}"
      set -- "\${1}" "\${2% *}"
      if gt "\${#2}" "\$(( ${len_cmd} + 9 ))" && lt "\${#2}" "\${COLUMNS}"
      then
        cols="\$(( \${#2} + 1 ))"
      fi
    fi
    printf '%s\\n' "\${_buf:0:\${cols}}"
    _buf="\${_buf:\${cols}}"
  }

  on checkwinsize

  # (:;:) is a micro sleep to ensure the variables are exported immediately.
  (:;:)

  local desc _buf
  local -a split

  version

  printf '\nCOMMANDS:\n' >&2
  ${help[@]@A}
  for desc in "\${help[@]}"
  do
    mapfile -t -d '|' split <<< "\${desc}"
    if gt "\${COLUMNS}" "\$(( ${len_cmd} + 9 ))"
    then
      printf -v _buf -- '        %-${len_cmd}s %s' "\${split[0]}" "\${split[1]%$'\n'}"
      cut_line "\${_buf}"
      while gt "\${#_buf}" '0'
      do
        printf -v _buf '        %${len_cmd}s %s' '' "\${_buf}"
        cut_line "\${_buf}"
      done
    else
      printf '\t%s\t%s' "\${split[0]}" "\${split[1]}"
    fi
  done >&2

  off checkwinsize
  unset -f cut_line
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
