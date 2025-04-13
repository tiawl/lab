# !/usr/bin/env -S jq -f

include "jq/module-color";

.[] |
  if length > 3
  then
    ("Error: protobuf2json should build JSON objects with unique key but jq found a JSON object with more than one key" | halt_error(1))
  elif has("vertexes")
  then
    (.vertexes |
      if any(.[]; has("started")) and any(.[]; has("completed"))
      then
        (.[] | select(has("name")) | colored($req_id; $color) + " > image build " + $image + " > " + .name)
      else
        empty
      end)
  elif has("statuses")
  then
    (.statuses |
      if any(.[]; has("started")) and any(.[]; has("completed"))
      then
        (.[] | select(has("ID")) | colored($req_id; $color) + " > image build " + $image + " > " + .ID)
      else
        empty
      end)
  elif has("warnings")
  then
    (.warnings[] | select(has("short")) | colored($req_id; $color) + " > image build " + $image + " > [WARNING] " + .short)
  else
    ("Error: Unknown protobuf message type: " + keys_unsorted[0] + "\n" | halt_error(1))
  end
