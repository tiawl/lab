#! /usr/bin/env bats

setup () {
  source src/utils.sh
  on errexit inherit_errexit errtrace functrace noclobber nounset pipefail lastpipe extglob
}
export -f setup

@test "simple defer" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup'"
      echo "${FUNCNAME[0]}: Init"
      echo "${FUNCNAME[0]}: Main loop"
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '3'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup'
}

@test "[false] simple defer" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup'"
      echo "${FUNCNAME[0]}: Init"
      echo "${FUNCNAME[0]}: Main loop"
      false
      echo 'This should never be displayed'
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  not eq "${status}" '0'
  eq "${#lines[@]}" '3'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup'
}

@test "multiple defers" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Removing temporary file'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
      echo "${FUNCNAME[0]}: Init"
      echo "${FUNCNAME[0]}: Main loop"
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '5'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Removing temporary file'
  str eq "${lines[4]}" 'a:   Freeing memory'
}

@test "[false] multiple defers" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Removing temporary file'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
      echo "${FUNCNAME[0]}: Init"
      echo "${FUNCNAME[0]}: Main loop"
      false
      echo 'This should never be displayed'
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  not eq "${status}" '0'
  eq "${#lines[@]}" '5'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Removing temporary file'
  str eq "${lines[4]}" 'a:   Freeing memory'
}

@test "[return 1] multiple defers" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Removing temporary file'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
      echo "${FUNCNAME[0]}: Init"
      echo "${FUNCNAME[0]}: Main loop"
      return 1
      echo 'This should never be displayed'
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  not eq "${status}" '0'
  eq "${#lines[@]}" '5'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Removing temporary file'
  str eq "${lines[4]}" 'a:   Freeing memory'
}

@test "[handled false] multiple defers" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Removing temporary file'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
      echo "${FUNCNAME[0]}: Init"
      false
      echo "${FUNCNAME[0]}: Main loop"
    }

    if not a; then :; fi
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '5'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Removing temporary file'
  str eq "${lines[4]}" 'a:   Freeing memory'
}

@test "[handled return 1] multiple defers" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Removing temporary file'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
      echo "${FUNCNAME[0]}: Init"
      echo "${FUNCNAME[0]}: Main loop"
      return 1
      echo 'This should never be displayed'
    }

    if not a; then :; fi
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '5'
  str eq "${lines[0]}" 'a: Init'
  str eq "${lines[1]}" 'a: Main loop'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Removing temporary file'
  str eq "${lines[4]}" 'a:   Freeing memory'
}

@test "nested functions 1" {
  run_me () {
    setup

    b () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
    }

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Releasing resources'"

      b
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '4'
  str eq "${lines[0]}" 'b: Cleanup:'
  str eq "${lines[1]}" 'b:   Freeing memory'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Releasing resources'
}

@test "nested functions 2" {
  run_me () {
    setup

    e () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Cook a cake'"
    }

    d () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Wash the car'"

      e
    }

    c () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Remove cache'"

      d
    }

    b () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
    }

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Releasing resources'"

      b
      c
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
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

@test "[false] nested functions" {
  run_me () {
    setup

    b () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
      false
      echo 'This should never be displayed'
    }

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Releasing resources'"

      b
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  not eq "${status}" '0'
  eq "${#lines[@]}" '4'
  str eq "${lines[0]}" 'b: Cleanup:'
  str eq "${lines[1]}" 'b:   Freeing memory'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Releasing resources'
}

@test "[return 1] nested functions" {
  run_me () {
    setup

    b () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
      return 1
      echo 'This should never be displayed'
    }

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Releasing resources'"

      b
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  not eq "${status}" '0'
  eq "${#lines[@]}" '4'
  str eq "${lines[0]}" 'b: Cleanup:'
  str eq "${lines[1]}" 'b:   Freeing memory'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Releasing resources'
}

@test "[handled false] nested functions" {
  run_me () {
    setup

    b () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      false
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
    }

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Releasing resources'"

      b
    }

    if not a; then :; fi
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '4'
  str eq "${lines[0]}" 'b: Cleanup:'
  str eq "${lines[1]}" 'b:   Freeing memory'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Releasing resources'
}

@test "[handled return 1] nested functions" {
  run_me () {
    setup

    b () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
      return 1
      echo 'This should never be displayed'
    }

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Releasing resources'"

      if not b; then return 1; fi
      echo 'This should never be displayed too'
    }

    if not a; then :; fi
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '4'
  str eq "${lines[0]}" 'b: Cleanup:'
  str eq "${lines[1]}" 'b:   Freeing memory'
  str eq "${lines[2]}" 'a: Cleanup:'
  str eq "${lines[3]}" 'a:   Releasing resources'
}

@test "recursive function" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[*]:0:${1}}: Cleanup:'"
      defer "echo '${FUNCNAME[*]:0:${1}}:   Removing temporary file'"

      if lt "${1}" '3'
      then
        a "$(( ${1} + 1 ))"
      fi
    }

    a 1
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '6'
  str eq "${lines[0]}" 'a a a: Cleanup:'
  str eq "${lines[1]}" 'a a a:   Removing temporary file'
  str eq "${lines[2]}" 'a a: Cleanup:'
  str eq "${lines[3]}" 'a a:   Removing temporary file'
  str eq "${lines[4]}" 'a: Cleanup:'
  str eq "${lines[5]}" 'a:   Removing temporary file'
}

@test "[false] recursive function" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[*]:0:${1}}: Cleanup:'"
      defer "echo '${FUNCNAME[*]:0:${1}}:   Removing temporary file'"

      if lt "${1}" '3'
      then
        a "$(( ${1} + 1 ))"
      else
        false
      fi
    }

    a 1
  }
  export -f run_me

  run bash -c 'run_me'
  not eq "${status}" '0'
  eq "${#lines[@]}" '6'
  str eq "${lines[0]}" 'a a a: Cleanup:'
  str eq "${lines[1]}" 'a a a:   Removing temporary file'
  str eq "${lines[2]}" 'a a: Cleanup:'
  str eq "${lines[3]}" 'a a:   Removing temporary file'
  str eq "${lines[4]}" 'a: Cleanup:'
  str eq "${lines[5]}" 'a:   Removing temporary file'
}

@test "[return 1] recursive function" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[*]:0:${1}}: Cleanup:'"
      defer "echo '${FUNCNAME[*]:0:${1}}:   Removing temporary file'"

      if lt "${1}" '3'
      then
        a "$(( ${1} + 1 ))"
      else
        return 1
      fi
    }

    a 1
  }
  export -f run_me

  run bash -c 'run_me'
  not eq "${status}" '0'
  eq "${#lines[@]}" '6'
  str eq "${lines[0]}" 'a a a: Cleanup:'
  str eq "${lines[1]}" 'a a a:   Removing temporary file'
  str eq "${lines[2]}" 'a a: Cleanup:'
  str eq "${lines[3]}" 'a a:   Removing temporary file'
  str eq "${lines[4]}" 'a: Cleanup:'
  str eq "${lines[5]}" 'a:   Removing temporary file'
}

@test "[handled false] recursive function" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[*]:0:${1}}: Cleanup:'"
      if eq "${1}" '3'
      then
        false
      fi
      defer "echo '${FUNCNAME[*]:0:${1}}:   Removing temporary file'"

      if lt "${1}" '3'
      then
        a "$(( ${1} + 1 ))"
      fi
    }

    if not a 1; then :; fi
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '6'
  str eq "${lines[0]}" 'a a a: Cleanup:'
  str eq "${lines[1]}" 'a a a:   Removing temporary file'
  str eq "${lines[2]}" 'a a: Cleanup:'
  str eq "${lines[3]}" 'a a:   Removing temporary file'
  str eq "${lines[4]}" 'a: Cleanup:'
  str eq "${lines[5]}" 'a:   Removing temporary file'
}

@test "[handled return 1] recursive function" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[*]:0:${1}}: Cleanup:'"
      if eq "${1}" '3'
      then
        return 1
      fi
      defer "echo '${FUNCNAME[*]:0:${1}}:   Removing temporary file'"

      if lt "${1}" '3'
      then
        a "$(( ${1} + 1 ))" || :
      fi
    }

    if not a 1; then :; fi
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '5'
  str eq "${lines[0]}" 'a a a: Cleanup:'
  str eq "${lines[1]}" 'a a: Cleanup:'
  str eq "${lines[2]}" 'a a:   Removing temporary file'
  str eq "${lines[3]}" 'a: Cleanup:'
  str eq "${lines[4]}" 'a:   Removing temporary file'
}

@test "nested defers" {
  run_me () {
    setup

    b () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
    }

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Releasing resources'"
      defer 'b'
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '4'
  str eq "${lines[0]}" 'a: Cleanup:'
  str eq "${lines[1]}" 'a:   Releasing resources'
  str eq "${lines[2]}" 'b: Cleanup:'
  str eq "${lines[3]}" 'b:   Freeing memory'
}

@test "[false] nested defers" {
  run_me () {
    setup

    b () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
      false
    }

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Releasing resources'"
      defer 'b'
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  not eq "${status}" '0'
  eq "${#lines[@]}" '4'
  str eq "${lines[0]}" 'a: Cleanup:'
  str eq "${lines[1]}" 'a:   Releasing resources'
  str eq "${lines[2]}" 'b: Cleanup:'
  str eq "${lines[3]}" 'b:   Freeing memory'
}

@test "[return 1] nested defers" {
  run_me () {
    setup

    b () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Freeing memory'"
      return 1
    }

    a () {
      defer "echo '${FUNCNAME[0]}: Cleanup:'"
      defer "echo '${FUNCNAME[0]}:   Releasing resources'"
      defer 'b'
    }

    a
  }
  export -f run_me

  run bash -c 'run_me'
  not eq "${status}" '0'
  eq "${#lines[@]}" '4'
  str eq "${lines[0]}" 'a: Cleanup:'
  str eq "${lines[1]}" 'a:   Releasing resources'
  str eq "${lines[2]}" 'b: Cleanup:'
  str eq "${lines[3]}" 'b:   Freeing memory'
}

@test "nested defers into recursive function" {
  run_me () {
    setup

    a () {
      defer "echo '${FUNCNAME[0]} ${1}: Cleanup:'"
      defer "echo '${FUNCNAME[0]} ${1}:   Removing temporary file'"

      if lt "${1}" '3'
      then
        defer "a '$(( ${1} + 1 ))'"
      fi
    }

    a 1
  }
  export -f run_me

  run bash -c 'run_me'
  eq "${status}" '0'
  eq "${#lines[@]}" '6'
  str eq "${lines[0]}" 'a 1: Cleanup:'
  str eq "${lines[1]}" 'a 1:   Removing temporary file'
  str eq "${lines[2]}" 'a 2: Cleanup:'
  str eq "${lines[3]}" 'a 2:   Removing temporary file'
  str eq "${lines[4]}" 'a 3: Cleanup:'
  str eq "${lines[5]}" 'a 3:   Removing temporary file'
}
