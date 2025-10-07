#! /bin/sh

dry () {
  ./setup.sh
  placid routine dry ./routines/lab.yml | cat -n
}

dry "${@}"
