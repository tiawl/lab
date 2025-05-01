# !/usr/bin/env --split-string gojq --from-file

# TODO:
# - command
# - register
# - op:
#   - and
#   - or
#   - [[ ]]
# - arith
# - while/for/case
# - recursive if/while/for/case
# - functions
# - on/off

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
            "runner: Bad variable name: \"" + $var.var + "\"\n" | halt_error(1)
          ) end
      ) else (
        "runner: Unknown object type: \"" + keys[0] + "\"\n" | halt_error(1)
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
      "runner: Unknown type: \"" + type + "\"\n" | halt_error(1)
    ) end
);

def task_image_builder(prefix): (
  . as $builder |
  ($builder | keys[0]) as $key |
    if has("prune") then (
      .prune as $prune | prefix + $key + " prune"
    ) else (
      "runner: Unknown image builder task type: \"" + $key + "\"\n" | halt_error(1)
    ) end
);

def task_image_tag(prefix): (
  . as $tag |
  ($tag | keys[0]) as $key |
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
      "runner: Unknown image tag task type: \"" + $key + "\"\n" | halt_error(1)
    ) end
);

def task_image(prefix): (
  . as $image |
  ($image | keys[0]) as $key |
    if has("tag") then (
      .tag | task_image_tag(prefix + $key + " ")
    ) elif has("builder") then (
      .builder | task_image_builder(prefix + $key + " ")
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
      "runner: Unknown image task type: \"" + $key + "\"\n" | halt_error(1)
    ) end
);

def task_container_resource(prefix): (
  . as $resource |
  ($resource | keys[0]) as $key |
    if has("copy") then (
      .copy as $copy | prefix + $key + " " +
      ($copy.name | sanitize) + " " +
      ($copy.src | sanitize) + " " +
      ($copy.dest | sanitize)
    ) else (
      "runner: Unknown container resource task type: \"" + $key + "\"\n" | halt_error(1)
    ) end
);

def task_container(prefix): (
  . as $container |
  ($container | keys[0]) as $key |
    if has("resource") then (
      .resource | task_container_resource(prefix + $key + " ")
    ) elif has("create") then (
      .create as $create | prefix + $key + " " +
        ($create.name | sanitize) + " " +
        ($create.image | sanitize) + " " +
        ($create.hostname | sanitize)
    ) else (
      "runner: Unknown container task type: \"" + $key + "\"\n" | halt_error(1)
    ) end
);

def pretask(i; args; prefix): (
  [
    prefix + "printf '\\033[38;5;" + (args.positional[(i % 30) + 2]) + "m\\033[1m" + (i + 1 | tostring) + "\\033[0m > %s\\n' \"" +
      (.[0] | gsub("\""; "'") | gsub("'(?<match>[^[:space:]']+)'"; "\(.match)")) + "\" >&2"
  ] + .
);

def task(i; args; prefix): (
  . as $task |
  if $task | isempty(.[]) then (
    []
  ) else (
    ($task | keys[0]) as $key |
    [
      if has("image") then (
        .image | task_image($key + " ")
      ) elif has("container") then (
        .container | task_container($key + " ")
      ) else (
        "runner: Unknown task type: \"" + $key + "\"\n" | halt_error(1)
      ) end
    ] | pretask(i; args; prefix)
  ) end
);

def conditional_inner(root; args): (
  if (.then | type != "array") then ("runner: Conditional \"then\" field must an array type but it is \"" + (.then | type) + "\"\n" | halt_error(1)) else . end |
  . as $inner |
  if ($inner | ((. | type == "object") and (. | keys | length == 1) and (. | keys[0] == "then"))) then (
    {
      op: {
        bash: {
          before: "",
          after: ""
        },
        yml: {}
      },
      root: root
    }
  ) else (
    {
      op: ($inner | op),
      root: (root | setpath(["__internal__", "i"]; .__internal__.i + 1))
    }
  ) end | . as $op_root | $op_root.op as $op | $op_root.root as $root |
  ($root.__internal__.i) as $cond_i |
  ([
    foreach ($inner | .then[]) as $item ({root: $root}; .root.__internal__.i += 1; . as $dot | . + {then: ($item | task($dot.root.__internal__.i; args; "    ") | join("\n    "))})
  ]) |
    {
      cond: ($op.bash.before + ($op.yml | task($cond_i; args; "") | join("; ")) + $op.bash.after),
      then: ([.[].then] | join("\n")),
      root: ([.[].root] | last)
    }
);

def conditional(root; args): (
  . as $conditional |
  ($conditional.if | conditional_inner(root; args) | .) as $first |
  [
    $first
  ] as $return |
    $conditional | if has("else") then (
      $return + [
        foreach $conditional.else[] as $item ({root: $first.root}; . as $dot | $item | conditional_inner($dot.root; args); .)
      ]
    ) else (
      $return
    ) end | . as $return | $return
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
    . as $root |
    $root.run[] |
      if has("harden") then (
        {
          bash: ("  harden " + (.harden | sanitize)),
          internal: $root.__internal__
        }
      ) elif has("assign") then (
        {
          bash: (. as $assign |
            "  local " + (if $assign.type == "map" then ("-A ")
            elif $assign.type == "array" then ("-a ")
            elif $assign.type == "ref" then "-n"
            elif $assign.type == "string" or $assign.type == "" or $assign.type == null then ""
            else (
              "runner: Unknown assign.type: \"" + $assign.type + "\"\n" | halt_error(1)
            ) end) + ($assign.assign | sanitize) + (
              if ($assign | has("key")) then ("[" + ($assign.key | sanitize) + "]") else "" end
            ) + (
              if ($assign | has("value")) then ("=" + ($assign.value | sanitize) + "") else "" end)
            ),
          internal: $root.__internal__
        }
      ) elif has("readonly") then (
        {
          bash: ("  readonly " + (.readonly | sanitize)),
          internal: $root.__internal__
        }
      ) elif has("if") then (
        . | conditional($root; $ARGS) as $return |
          {
            bash: ("  if " + $return[0].cond + "\n  then\n" + $return[0].then + (if ($return[1:] | length > 0) then ([$return[1:][] as $item | $item | (if (.cond | length > 0) then ("\n  elif " + $item.cond + "\n  then\n") else "\n  else\n" end) + $item.then] | join("")) else "" end) + "\n  fi; "),
            internal: $return | last | .root.__internal__
          }
      ) elif has("defer") then (
        ($root | setpath(["__internal__", "i"]; .__internal__.i + 1)) as $root |
        {
          bash: ("  defer '" + ([.defer | task($root.__internal__.i; $ARGS; "")[] | gsub("'"; "'\"'\"'")] | join("'\n  defer '")) + "'"),
          internal: $root.__internal__
        }
      ) else (
        ($root | setpath(["__internal__", "i"]; .__internal__.i + 1)) as $root |
        {
          bash: (. | task($root.__internal__.i; $ARGS; "  ") | join("\n  ")),
          internal: $root.__internal__
        }
      ) end |
        . as $res |
        ($root | setpath(["__internal__"]; $res.internal)) as $root |
        $res.bash
  ] | join("\n")
) + "
}

" + $runner + " \"${@}\""
