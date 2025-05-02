#! /usr/bin/env bash

shebangless () {
  sed '/^#\s*!/{N;/\n$/d;s/.*\n//;p;d}' "${1}"
}

# executed by setup.sh
compile () {
  on errexit noclobber nounset pipefail lastpipe extglob

  harden base64
  harden cat
  harden git
  harden mkdir
  harden rm
  harden sed

  local name version help
  name='piplop'
  version="$(git -C "${SDIR}" describe --match *.*.* --tags --abbrev=9)"
  version="${version%-*}"
  version="${version%\.*}.${version#*-}"
  help="$(on globstar
    for src in "${SDIR}/src"/**/*
    do
      if is file "${src}"
      then
        sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_]*\)\s*()\s*{\s*#HELP/\t\1\t/p' "${src}" | sed ':loop; s/^\(\t[^\t]*\)_/\1 /; t loop'
      fi
    done)"
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
      shebangless "${src}"
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

${name} () {
  if str empty "\${${name^^}_REEXEC_WITH_EMPTY_ENV:-}"
  then
    \\command exec -c env -i ${name^^}_REEXEC_WITH_EMPTY_ENV='yes' bash --norc --noprofile "\${BASH_SOURCE[0]}" "\${@}" || \\command exit 1
  fi

  on errexit noclobber nounset pipefail lastpipe extglob

  bash_setup

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

  orchestrator "\${@}"
}

${name} "\${@}"
EOF
  chmod 0700 "${SDIR}/bin/${name}"
}

compile "${@}"
