#! /usr/bin/env bash

tag_list () {
  shift

  image list "${1}:*" | sed 's/^[^:]*://'
}
