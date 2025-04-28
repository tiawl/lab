#! /usr/bin/env bash

image_prune () { #HELP <pattern>\t\t\t\t\t\t\tRemove unused images matching <pattern>
  shift
  local img
  set -f
  for img in $(image list "${1}")
  do
    image remove "${img%:*}" "${img#*:}"
  done
  set +f
}
