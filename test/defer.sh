#!/usr/bin/env bats

source src/utils.sh

defer () {
  local stage pfx ppfx sep uuid prev_return_trap
  stage='0'
  sep='_'
  prev_return_trap="$(trap -p RETURN)"
  prev_return_trap="${prev_return_trap#"trap -- '' RETURN"}"
  uuid="${FUNCNAME[*]:1} ${BASH_LINENO[*]:2}"
  uuid="${uuid// /"${sep}"}"
  ppfx="${sep}${sep}deferred${sep}"
  pfx="${ppfx}${FUNCNAME[1]}${sep}${uuid}${sep}"
  readonly pfx ppfx sep uuid prev_return_trap
  if is not func "${pfx}0"
  then
    trap -- "
if str eq \"\${FUNCNAME[0]}\" \"${FUNCNAME[1]}\"
then
  ${pfx}0
  ${prev_return_trap:-trap - RETURN}
fi
" RETURN
  fi
  while is func "${pfx}$(( ++stage ))"; do :; done
  (( stage-- ))
  source /proc/self/fd/0 <<< "
    ${pfx}${stage} () {
      local before after
      before=\"\$(compgen -A function -X '!${ppfx}*0')\"
      ${*}
      after=\"\$(compgen -A function -X '!${ppfx}*0')\"
      if str not eq \"\${before}\" \"\${after}\"
      then
        local deferred
        for deferred in \$(gojq -n -r '\$ARGS.positional | group_by(.) | .[] | select(length == 1) | .[0]' --args \"\${before[@]}\" \"\${after[@]}\")
        do
          \${deferred}
        done
      fi
      ${pfx}$(( stage + 1 ))
      unset \"\${FUNCNAME[0]}\"
    }
    ${pfx}$(( stage + 1 )) () {
      unset \"\${FUNCNAME[0]}\"
    }
  "
}

on functrace

@test "simple defer in one function" {
  a() {
    defer "echo '${FUNCNAME[0]}: Cleanup'"
    echo "${FUNCNAME[0]}: Init"
    echo "${FUNCNAME[0]}: Main loop"
  }

  run a
  eq "${status}" '0'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup'
}

@test "multiple defers in one function" {
  a() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Removing temporary file'"
    defer "echo '${FUNCNAME[0]}:   Freeing memory'"
    echo "${FUNCNAME[0]}: Init"
    echo "${FUNCNAME[0]}: Main loop"
  }

  run a
  eq "${status}" '0'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Removing temporary file'
  str eq "${lines[4]}" 'a:   Freeing memory'
}

@test "multiple defers into nested function 1" {
  b() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Freeing memory'"
  }

  a() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Releasing resources'"

    b
  }

  #set -x
  run a
  eq "${status}" '0'
  str eq "${lines[0]}" 'b: Cleanup:'
  str eq "${lines[1]}" 'b:   Freeing memory'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Releasing resources'
}

@test "multiple defers into nested function 2" {
  e() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Cook a cake'"
  }

  d() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Wash the car'"

    e
  }

  c() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Remove cache'"

    d
  }

  b() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Freeing memory'"
  }

  a() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Releasing resources'"

    b
    c
  }

  run a
  eq "${status}" '0'
  str eq "${lines[0]}" 'b: Cleanup:'
  str eq "${lines[1]}" 'b:   Freeing memory'
  str eq "${lines[2]}" 'e: Cleanup:'
  str eq "${lines[3]}" 'e:   Cook a cake'
  str eq "${lines[4]}" 'd: Cleanup:'
  str eq "${lines[5]}" 'd:   Wash the car'
  str eq "${lines[6]}" 'c: Cleanup:'
  str eq "${lines[7]}" 'c:   Remove cache'
  str eq "${lines[8]}" 'a: Cleanup:'
  str eq "${lines[9]}" 'a:   Releasing resources'
}

# "recursive" case
# "error" case
# "use in defer in function that use defer" case
