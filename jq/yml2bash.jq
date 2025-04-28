# !/usr/bin/env --split-string gojq --from-file

def sanitize: (
  [
    .[] |
      if has("literal") then (
        "'" + .literal +  "'"
      ) elif has("var") then (
        . as $var |
          if ($var.var | test("^[a-zA-Z_][a-zA-Z0-9_]*$")) then (
            "\"${" + $var.var + (if ($var | has("key")) then ("[" + ($var.key | sanitize) + "]") else "" end) + "}\""
          ) else (
            "yml2bash: Bad variable name: \"" + $var.var + "\"\n" | halt_error(1)
          ) end
      ) else (
        "yml2bash: Unknown object type: \"" + keys[0] + "\"\n" | halt_error(1)
      ) end
  ] | join("")
);

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
          yml: .yml
        }
      ) else (
        {
          bash: {
            before: "",
            after: ""
          },
          yml: .
        }
      ) end
    ) else (
      "yml2bash: Unknown type: \"" + type + "\"\n" | halt_error(1)
    ) end
);

def task_image_tag(prefix): (
  . as $dot |
  ($dot | keys[0]) as $key |
    if has("defined") then (
      .defined as $defined | prefix + $key + " " +
        ($defined.image | sanitize) + " " +
        ($defined.tag | sanitize)
    ) elif has("create") then (
      .create as $create | prefix + $key + " " +
        ($create.from.image | sanitize) + " " +
        ($create.from.tag | sanitize) + " " +
        ($create.to.image | sanitize) + " " +
        ($create.to.tag | sanitize)
    ) else (
      "yml2bash: Unknown image tag task type: \"" + $key + "\"\n" | halt_error(1)
    ) end
);

def task_image(prefix): (
  . as $dot |
  ($dot | keys[0]) as $key |
    if has("tag") then (
      .tag | task_image_tag(prefix + $key + " ")
    ) elif has("pull") then (
      .pull as $pull | prefix + $key + " " +
        ($pull.registry | sanitize) + " " +
        ($pull.library | sanitize) + " " +
        ($pull.image | sanitize) + " " +
        ($pull.tag | sanitize)
    ) elif has("remove") then (
      .remove as $remove | prefix + $key + " " +
        ($remove.image | sanitize) + " " +
        ($remove.tag | sanitize)
    ) elif has("prune") then (
      .prune as $prune | prefix + $key + " " +
        ($prune.matching | sanitize)
    ) elif has("build") then (
      .build as $build | prefix + $key + " " +
        ($build.image | sanitize) + " " +
        ($build.context | sanitize) + " " +
        ($build.args | length | tostring) + " " +
        ([$build.args[].key | sanitize] | join(" ")) + " " +
        ([$build.args[].value | sanitize] | join(" "))
    ) else (
      "yml2bash: Unknown image task type: \"" + $key + "\"\n" | halt_error(1)
    ) end
);

def pretask(i; args; prefix): (
  prefix + "printf '\\033[38;5;" + (args.positional[(i % 30) + 2]) + "m\\033[1m%s\\033[0m > %s\\n' \"$(( ++req_id ))\" \"${*}\" >&2; " + .
);

def task(i; args; prefix): (
  . as $dot |
  ($dot | keys[0]) as $key |
    if has("image") then (
      .image | task_image($key + " ") | pretask(i; args; prefix)
    ) else (
      "yml2bash: Unknown task type: \"" + $key + "\"\n" | halt_error(1)
    ) end
);

(input_filename | sub(".*/";"") | sub("\\.yml$";"")) as $name |
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
          bash: ("  harden " + (.harden | sanitize)),
          internal: $dot.__internal__
        }
      ) elif has("assign") then (
        {
          bash: (. as $assign |
            "  local " + (if $assign.type == "map" then ("-A ")
            elif $assign.type == "array" then ("-a ")
            elif $assign.type == "ref" then "-n"
            elif $assign.type == "string" or $assign.type == "" or $assign.type == null then ""
            else (
              "runner exec: Unknown assign.type: \"" + $assign.type + "\"\n" | halt_error(1)
            ) end) + ($assign.assign | sanitize) + (
              if ($assign | has("key")) then ("[" + ($assign.key | sanitize) + "]") else "" end
            ) + (
              if ($assign | has("value")) then ("=" + ($assign.value | sanitize) + "") else "" end)
            ),
          internal: $dot.__internal__
        }
      ) elif has("readonly") then (
        {
          bash: ("  readonly " + (.readonly | sanitize)),
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
                $op.bash.before + ($op.yml | task($if_i; $ARGS; "")) + $op.bash.after
              ) + "\n  then\n" + $then + "\n  fi; "),
            internal: $dot.__internal__
          }
      ) else (
        ($dot | setpath(["__internal__", "i"]; .__internal__.i + 1)) as $dot |
        {
          bash: (. | task($dot.__internal__.i; $ARGS; "  ")),
          internal: $dot.__internal__
        }
      ) end |
        . as $res |
        ($dot | setpath(["__internal__"]; $res.internal)) as $dot |
        $res.bash
  ] | join("\n")
) + "
}

" + $runner + " \"${@}\""
