#! /usr/bin/env bash

image_tag_list () { #HELP <image>\t\t\t\t\t\t\tList tags referring to <image>
  shift

  image list "${1}:*" | sed 's/^[^:]*://'
}
