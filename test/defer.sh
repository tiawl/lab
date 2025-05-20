#!/usr/bin/env bats

source src/utils.sh

defer () {
  local stage pfx ppfx sep old_ifs prev_return_trap min max x
  local -a caller
  old_ifs="${IFS}"
  stage='0'
  sep='_'
  prev_return_trap="$(trap -p RETURN)"
  prev_return_trap="${prev_return_trap#"trap -- '' RETURN"}"
  readonly old_ifs sep prev_return_trap

  caller=("${BASH_LINENO[@]:2}" "${FUNCNAME[@]:1}")
  min='0'
  max="$(( ${#caller[@]} -1 ))"
  while lt "${min}" "${max}"
  do
    x="${caller["${min}"]}"
    caller["${min}"]="${caller["${max}"]}"
    caller["${max}"]="${x}"
    (( min++, max-- ))
  done
  ppfx="${sep}${sep}deferred${sep}"
  IFS="${sep}"
  pfx="${ppfx}${caller[*]}${sep}"
  IFS="${old_ifs}"
  readonly pfx ppfx caller

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
      on noglob
      before=(\$(compgen -A function -X '!${ppfx}*0'))
      off noglob
      ${*}
      on noglob
      after=(\$(compgen -A function -X '!${ppfx}*0'))
      off noglob
      if str not eq \"\${before[*]}\" \"\${after[*]}\"
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

@test "simple defer" {
  a() {
    defer "echo '${FUNCNAME[0]}: Cleanup'"
    echo "${FUNCNAME[0]}: Init"
    echo "${FUNCNAME[0]}: Main loop"
  }

  run a
  eq "${status}" '0'
  eq "${#lines[@]}" '3'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup'
}

@test "multiple defers" {
  a() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Removing temporary file'"
    defer "echo '${FUNCNAME[0]}:   Freeing memory'"
    echo "${FUNCNAME[0]}: Init"
    echo "${FUNCNAME[0]}: Main loop"
  }

  run a
  eq "${status}" '0'
  eq "${#lines[@]}" '5'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Removing temporary file'
  str eq "${lines[4]}" 'a:   Freeing memory'
}

@test "nested function 1" {
  b() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Freeing memory'"
  }

  a() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Releasing resources'"

    b
  }

  run a
  eq "${status}" '0'
  eq "${#lines[@]}" '4'
  str eq "${lines[0]}" 'b: Cleanup:'
  str eq "${lines[1]}" 'b:   Freeing memory'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Releasing resources'
}

@test "nested function 2" {
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
  eq "${#lines[@]}" '10'
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

@test "recursive function" {
  a() {
    defer "echo '${FUNCNAME[0]} ${1}: Cleanup:'"
    defer "echo '${FUNCNAME[0]} ${1}:   Removing temporary file'"

    if lt "${1}" '3'
    then
      a "$(( ${1} + 1 ))"
    fi
  }

  run a 1
  eq "${status}" '0'
  eq "${#lines[@]}" '6'
  str eq "${lines[0]}" 'a 3: Cleanup:'
  str eq "${lines[1]}" 'a 3:   Removing temporary file'
  str eq "${lines[2]}" 'a 2: Cleanup:'
  str eq "${lines[3]}" 'a 2:   Removing temporary file'
  str eq "${lines[4]}" 'a 1: Cleanup:'
  str eq "${lines[5]}" 'a 1:   Removing temporary file'
}

@test "nested defers" {
  b() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Freeing memory'"
  }

  a() {
    defer "echo '${FUNCNAME[0]}: Cleanup:'"
    defer "echo '${FUNCNAME[0]}:   Releasing resources'"
    defer 'b'
  }

  run a
  eq "${status}" '0'
  eq "${#lines[@]}" '4'
  str eq "${lines[0]}" 'a: Cleanup:'
  str eq "${lines[1]}" 'a:   Releasing resources'
  str eq "${lines[2]}" 'b: Cleanup:'
  str eq "${lines[3]}" 'b:   Freeing memory'
}

@test "nested defers into recursive function" {
  a() {
    defer "echo '${FUNCNAME[0]} ${1}: Cleanup:'"
    defer "echo '${FUNCNAME[0]} ${1}:   Removing temporary file'"

    if lt "${1}" '3'
    then
      defer "a '$(( ${1} + 1 ))'"
    fi
  }

  run a 1
  eq "${status}" '0'
  eq "${#lines[@]}" '6'
  str eq "${lines[0]}" 'a 1: Cleanup:'
  str eq "${lines[1]}" 'a 1:   Removing temporary file'
  str eq "${lines[2]}" 'a 2: Cleanup:'
  str eq "${lines[3]}" 'a 2:   Removing temporary file'
  str eq "${lines[4]}" 'a 3: Cleanup:'
  str eq "${lines[5]}" 'a 3:   Removing temporary file'
}

# "error" case
