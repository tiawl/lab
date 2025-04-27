# !/usr/bin/env --split-string gojq --from-file

def op: (
  . |
    if (type == "object") then (
      if has("not") then (
        (.not | op) |
        {
          bash: {
            before: ("! { " + .bash.before),
            after: (.bash.after + "; }")
          },
          json: .json
        }
      ) else (
        {
          bash: {
            before: "",
            after: ""
          },
          json: .
        }
      ) end
    ) else (
      "json2bash: Unknown type into op function: \"" + type + "\"\n" | halt_error(1)
    ) end
);

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

def pretask(i; args; prefix): (
  prefix + "set -- " + ((i % 30) + 2 | tostring) + " " + (args.positional | join(" ")) + "; printf '%b\\033[1m%s\\033[0m > %s\\n' \"\\033[38;5;${!1}m\" \"$(( ++req_id ))\" \"${*}\" >&2; set --; " + .
);

def task(i; args; prefix): (
  . |
    if has("image") then (
      keys[0] + " " + (.image | task_image) | pretask(i; args; prefix)
    ) else (
      "json2bash: Unknown task type: \"" + keys[0] + "\"\n" | halt_error(1)
    ) end
);

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
    .__internal__.i = -1 |
    . as $dot |
    $dot.run[] |
      if has("harden") then (
        {
          bash: ("  harden " + .harden),
          internal: $dot.__internal__
        }
      ) elif has("var") then (
        {
          bash: (. as $var |
            "  local " + (if $var.type == "map" then ("-A ")
            elif $var.type == "array" then ("-a ")
            elif $var.type == "string" then empty
            else (
              "runner exec: Unknown var.type: \"" + $var.type + "\"\n" | halt_error(1)
            ) end) + $var.var),
          internal: $dot.__internal__
        }
      ) elif has("readonly") then (
        {
          bash: ("  readonly " + .readonly),
          internal: $dot.__internal__
        }
      ) elif has("set") then (
        {
          bash: (. as $set |
            "  " + $set.set + (if ($set | has("key")) then ("[" + $set.key + "]") else empty end) + "=\"" + $set.value + "\""),
          internal: $dot.__internal__
        }
      ) elif has("if") and has("then") then (
        . as $conditional |
          ($conditional.if | op) as $op |
          ($dot | setpath(["__internal__", "i"]; .__internal__.i + 1)) as $dot |
          ($dot.__internal__.i) as $if_i |
          ([foreach $conditional.then[] as $item ($dot; .__internal__.i += 1; [., . as $dot | $item | task($dot.__internal__.i; $ARGS; "    ")])]) as $arr |
          ([$arr[][1]] | join("\n")) as $then |
          ([$arr[][0]] | last) as $dot |
          {
            bash: ("  if " + (
                $op.bash.before + ($op.json | task($if_i; $ARGS; "")) + $op.bash.after
              ) + "\n  then\n" + $then + "\n  fi; "),
            internal: $dot.__internal__
          }
      ) else (
        "json2bash: Unknown json object type: \"" + keys[0] + "\"\n" | halt_error(1)
      ) end |
        . as $res |
        ($dot | setpath(["__internal__"]; $res.internal)) as $dot |
        $res.bash
  ] | join("\n")
) + "
}

" + $runner
