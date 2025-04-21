#! /usr/bin/env bash

source_all () {
  local file

  source sh/urlencode.sh

  for file in sh/**/*.sh
  do
    source "${file}"
  done

  source sh/builder.sh
  source sh/image.sh
  source sh/container.sh
  source sh/tag.sh
  source sh/network.sh
  source sh/volume.sh
}

source_all
