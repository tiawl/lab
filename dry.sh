#! /bin/sh

dry () {
  ./setup.sh
  placid runner dry ./runners/lab.yml | cat -n
}

dry "${@}"
