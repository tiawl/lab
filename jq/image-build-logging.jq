# !/usr/bin/env --split-string gojq --from-file

import "module-color" as color;

def move_error_to_last_position:
  [
    . as $array |
    (
      $array[] |
      if has("vertexes")
      then
        (
          .vertexes |
          map(select(has("error") | not)) |
          select(length > 0) |
          {"vertexes": .}
        )
      else
        .
      end
    ),(
      $array[] |
      if has("vertexes")
      then
        (
          .vertexes |
          map(select(has("error"))) |
          select(length > 0) |
          {"vertexes": .}
        )
      else
        empty
      end
    )
  ];

. | move_error_to_last_position | .[] |
  if length > 1
  then
    ("Error: protobuf2json should build JSON objects with unique key but jq found a JSON object with more than one key" | halt_error(1))
  elif has("vertexes")
  then
    (
      .vertexes |
      if any(.[]; has("error"))
      then
        ("image build " + $image + " > " + color::text("[ERROR] " + .[].error + "\n"; 1) | halt_error(1))
      elif any(.[]; has("started")) and any(.[]; has("completed"))
      then
        (.[] | select(has("name")) | "image build " + $image + " > " + .name)
      else
        empty
      end
    )
  elif has("statuses")
  then
    (
      .statuses |
      if any(.[]; has("started")) and any(.[]; has("completed"))
      then
        (.[] | select(has("ID")) | "image build " + $image + " > " + .ID)
      else
        empty
      end
    )
  elif has("logs")
  then
    (.logs[] | select(has("msg")) | "image build " + $image + " > " + (.msg | rtrimstr("\n")))
  elif has("warnings")
  then
    (.warnings[] | select(has("short")) | "image build " + $image + " > " + color::text("[WARNING] " + .short; 3))
  else
    ("protobuf2json: Unknown protobuf message type: " + keys[0] + "\n" | halt_error(1))
  end
