# !/usr/bin/env --split-string gojq --from-file

def task_image_tag: (
  . | keys[0] +
    if has("defined") then (
      .defined as $defined | " \"" + $defined.image + "\" \"" + $defined.tag + "\""
    ) elif has("create") then (
      .create as $create | " \"" + $create.from.image + "\" \"" + $create.from.tag + "\" \"" + $create.to.image + "\" \"" + $create.to.tag + "\""
    ) else (
      "json2bash: Unknown image tag task type: \"" + keys[0] + "\"\n" | halt_error(1)
    ) end
);

def task_image: (
  . | keys[0] +
    if has("tag") then (
      " " + (.tag | task_image_tag)
    ) elif has("pull") then (
      .pull as $pull | " \"" + $pull.registry + "\" \"" + $pull.library + "\" \"" + $pull.image + "\" \"" + $pull.tag + "\""
    ) elif has("remove") then (
      .remove as $remove | " \"" + $remove.image + "\" \"" + $remove.tag + "\""
    ) elif has("prune") then (
      .prune as $prune | " \"" + $prune.matching + "\""
    ) else (
      "json2bash: Unknown image task type: \"" + keys[0] + "\"\n" | halt_error(1)
    ) end
);

def pretask(i; args): (
  "  set -- \"$(( (" + (i | tostring) + " % 30) + 1 + 1 ))\" " + (args.positional | join(" ")) + "
  printf '%b\\033[1m%s\\033[0m > %s\\n' \"\\033[38;5;${!1}m\" \"$(( ++req_id ))\" \"${*}\" >&2
  set --\n" + .
);

def task(i; args; spaces): (
  . |
    if has("image") then (
      {
        output: (spaces + keys[0] + " " + (.image | task_image) | pretask(i; args)),
        i: (i + 1)
      }
    ) else (
      "json2bash: Unknown task type: \"" + keys[0] + "\"\n" | halt_error(1)
    ) end
);

. as $dot |
0 as $i |
(input_filename | sub(".*/";"") | sub("\\.json$";"")) as $name |
("runner_" + $name) as $runner |
  $runner + " () {
  on errexit noclobber nounset pipefail lastpipe

  bash_setup

  harden id

  local user uid home runner_name
  user=\"${USER:-\"$(id --user --name)\"}\"
  uid=\"${UID:-\"$(id --user)\"}\"
  home=\"${HOME:-\"$(printf '%s' ~)\"}\"
  runner_name='" + $name + "'
  readonly user uid home runner_name

" + (
  [
    $dot.run[] |
      if has("harden") then (
        "  harden " + .harden
      ) elif has("var") then (
        .var as $var |
          "  local " + (if $var.type == "map" then ("-A ")
          elif $var.type == "array" then ("-a ")
          elif $var.type == "string" then empty
          else (
            "runner exec: Unknown var.type: \"" + $var.type + "\"\n" | halt_error(1)
          ) end) + $var.name
      ) elif has("readonly") then (
        "  readonly " + .readonly
      ) elif has("set") then (
        .set as $set |
          "  " + $set.name + (if ($set | has("key")) then ("[" + $set.key + "]") else empty end) + "=\"" + $set.value + "\""
      ) elif has("if") and has("then") then (
        . as $conditional |
          ($conditional.if |
            if has("not") then (
              .not | (task($i; $ARGS; "  if not ") as $task | $task.i as $i | $task.output)
            ) else (
              . | task($i; $ARGS; "  if ") as $task | $task.i as $i | $task.output
            ) end) +
          "\n  then\n" + ([$conditional.then[] | task($i; $ARGS; "    ") as $task | $task.i as $i | $task.output] | join("\n")) + "\n  fi"
      ) else (
        "json2bash: Unknown json object type: \"" + keys[0] + "\"\n" | halt_error(1)
      ) end
  ] | join("\n")
) + "
}

" + $runner
