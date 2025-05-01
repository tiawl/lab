# !/usr/bin/env --split-string gojq --from-file

# TODO:
# - more checks like conditional "then"
# - command: it should only be possible to run hardened command
# - register
# - op:
#   - and
#   - or
#   - [[ ]]
# - arith
# - while/for/case
# - functions
# - on/off

def indent(level): (
  (" " * ((level + 1) * 2)) + .
);

def sanitize: (
  map(
    if has("literal") then (
      "'" + .literal + "'"
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
  ) | join("")
);

def op: (

  def op_not: (
    (. | op) |
    {
      program: {
        before: ("! { " + .program.before),
        after: (.program.after + "; }")
      },
      yml: .yml
    }
  );

  if (type == "object") then (
    if has("not") then (
      .not | op_not
    ) else (
      {
        program: {
          before: "{ ",
          after: "; }"
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
        ($build.args | map(.key | sanitize) | join(" ")) + " " +
        ($build.args | map(.value | sanitize) | join(" "))
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

def xtrace_task(i; args; level): (
  [
    "printf '\\033[38;5;" + (args.positional[(i % 30) + 2]) + "m\\033[1m" + (i + 1 | tostring) + "\\033[0m > %s\\n' \"" +
      (.[0] | gsub("\""; "'") | gsub("'(?<match>[^[:space:]']+)'"; "\(.match)")) + "\" >&2"
  ] + .
);

def task(i; args; level): (
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
      ] | xtrace_task(i; args; level) | map(. | indent(level))
    ) end
);

def assign(level): (
  . as $assign |
    "local " + (
      if ($assign.type == "map") then (
        "-A "
      ) elif ($assign.type == "array") then (
        "-a "
      ) elif ($assign.type == "ref") then (
        "-n"
      ) elif ($assign.type == "string" or $assign.type == "" or $assign.type == null) then (
        ""
      ) else (
        "runner: Unknown assign.type: \"" + $assign.type + "\"\n" | halt_error(1)
      ) end
    ) + ($assign.assign | sanitize) + (
      if ($assign | has("key")) then (
        "[" + ($assign.key | sanitize) + "]"
      ) else "" end
    ) + (
      if ($assign | has("value")) then (
        "=" + ($assign.value | sanitize) + ""
      ) else "" end
    ) | indent(level)
);

def keyword(internal; level): (
  def conditional(internal; args; level): (
    def conditional_inner(internal; args; level): (
      # check then field is an array
      if (.then | type != "array") then (
        "runner: Conditional \"then\" field must an array type but it is \"" + (.then | type) + "\"\n" | halt_error(1)
      ) else . end |

      . as $inner |
        # "else" case
        if ($inner | ((. | type == "object") and (. | keys | length == 1) and (. | keys[0] == "then"))) then (
          {
            op: {
              program: {
                before: "",
                after: ""
              },
              yml: {}
            },
            internal: internal
          }
        # "if" and "elif" case
        ) else (
          {
            op: ($inner | op),
            internal: (internal | setpath(["i"]; .i + 1))
          }
        ) end |
        . as $op_internal |
        $op_internal.op as $op |
        $op_internal.internal as $internal |
        ($internal.i) as $cond_i |
        ([
          # upgrade .internal.i when iterating over "then" content
          foreach ($inner | .then[]) as $item (
            {
              internal: $internal
            };
            . as $dot | $item | keyword($dot.internal; level + 1) as $keyword |
            {
              then: $keyword.program,
              internal: $keyword.internal

            };
            .
          )
        ]) |
          {
            cond: ($op.program.before + ($op.yml | task($cond_i; args; -1) | join("; ")) + $op.program.after),
            then: (map(.then) | join("\n")),
            internal: (map(.internal) | last)
          }
    );

    . as $conditional |
    ($conditional.if | conditional_inner(internal; args; level) | .) as $if |
    {
      if: $if,
      else: []
    } as $return |
      $conditional |
      if has("else") then (
        $return | setpath(["else"]; .else + [
          # upgrade .internal.i when iterating "if"/"elif"/"else" statements
          foreach $conditional.else[] as $item (
            {
              internal: $if.internal
            };
            . as $dot | $item | conditional_inner($dot.internal; args; level);
            .
          )
        ])
      ) else (
        $return
      ) end
  );

  internal as $internal |
    if has("harden") then (
      {
        program: (("harden " + (.harden | sanitize)) | indent(level)),
        internal: $internal
      }
    ) elif has("assign") then (
      . | assign(level) |
        {
          program: .,
          internal: $internal
        }
    ) elif has("readonly") then (
      {
        program: (("readonly " + (.readonly | sanitize)) | indent(level)),
        internal: $internal
      }
    ) elif has("if") then (
      . | conditional($internal; $ARGS; level) as $conditional |
        {
          program: (
            (("if " + $conditional.if.cond + "\n") | indent(level)) +
            ("then\n" | indent(level)) + $conditional.if.then + "\n" + (
              if ($conditional.else | length > 0) then (
                $conditional.else | map(
                  . as $item | $item | (
                    if (.cond | length > 0) then (
                      (("elif " + $item.cond) | indent(level)) + "\n" +
                      ("then\n" | indent(level))
                    ) else (
                      "else\n" | indent(level)
                    ) end
                  ) + $item.then
                ) | join("\n") + "\n"
              ) else "" end
            ) + ("fi" | indent(level))
          ),
          internal: (
            if ($conditional.else | length == 0) then (
              $conditional.if
            ) else (
              $conditional.else | last
            ) end | .internal
          )
        }
    ) elif has("defer") then (
      ($internal | setpath(["i"]; .i + 1)) as $internal |
      {
        program: (.defer | task($internal.i; $ARGS; level) | map(gsub("'"; "'\"'\"'") | sub("^(?<match>[[:space:]]*)"; "\(.match)defer '") | sub("$"; "'")) | join("\n")),
        internal: $internal
      }
    ) else (
      ($internal | setpath(["i"]; .i + 1)) as $internal |
      {
        program: (. | task($internal.i; $ARGS; level) | join("\n")),
        internal: $internal
      }
    ) end
);

def main: (
  (input_filename | sub(".*/";"") | sub("\\.yml$";"")) as $name |
  ("runner_" + $name) as $runner |
  .internal = {
    i: -1,
    program: ($runner + " () {\n  on errexit noclobber nounset pipefail lastpipe\n\n  bash_setup\n\n  harden id\n\n  local user uid home runner_name\n  user=\"${USER:-\"$(id --user --name)\"}\"\n  uid=\"${UID:-\"$(id --user)\"}\"\n  home=\"${HOME:-\"$(printf '%s' ~)\"}\"\n  runner_name='" + $name + "'\n  readonly user uid home runner_name\n\n")
  } |
  . as $root |
    reduce $root.run[] as $item (
      $root.internal;
      . as $internal | $item | keyword($internal; 0) as $keyword |
        {
          i: $keyword.internal.i,
          program: ($internal.program + $keyword.program + "\n")
        }
    ) | .program + "}\n\n" + $runner + " \"${@}\""
);

. | main
