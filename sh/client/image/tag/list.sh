#! /usr/bin/env bash

image_tag_list () {
  shift

  image list "${1}:*" | sed 's/^[^:]*://'
}
