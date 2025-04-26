#! /usr/bin/env bash

shebangless () {
  sed '/^#\s*!/{N;/\n$/d;s/.*\n//;p;d}' "${1}"
}

# executed by setup.sh
compile () {
  on errexit noclobber nounset pipefail lastpipe

  harden mkdir
  harden git
  harden cat
  harden sed

  local name version
  name='bdzr'
  version="$(git -C "${SDIR}" describe --match *.*.* --tags --abbrev=9)"
  version="${version%-*}"
  version="${version%\.*}.${version#*-}"
  readonly name version

  local -A src
  src[utils_sh]="$(shebangless "${SDIR}/src/utils.sh")"
  readonly src

  mkdir -p "${SDIR}/bin"
  off noclobber
  cat <<EOF > "${SDIR}/bin/${name}.sh"
#! /usr/bin/env bash

${src[utils_sh]}

version () {
  printf '${version}\n'
}

help () {
  : TODO
}

${name} () {
  global -A sed jq buf
$(on globstar
  for dir in sed jq
  do
    for file in "${SDIR}/${dir}"/**/*
    do
      printf '  %s[%s]=%s\n' "${dir}" "$(basename "${file}" ".${dir}")" "'$(shebangless "${file}" | sed "s/'/'\"'\"'/g")'"
    done
  done)
  readonly sed jq buf
  : TODO
}

${name} "\${@}"
EOF
}

compile "${@}"
