#! /bin/sh

dry () {
  ./setup.sh
  placid runner dry ./runners/lab.yml
}

dry "${@}"
