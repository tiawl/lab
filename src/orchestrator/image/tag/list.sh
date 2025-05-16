#! /usr/bin/env bash

image_tag_list () { #HELP <image>|List tags referring to <image>
  shift

  image list "${1}:*" | sed 's/^[^:]*://'
}
