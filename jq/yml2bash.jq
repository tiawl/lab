# !/usr/bin/env --split-string gojq --from-file

# TODO:
# - more checks like conditional "then"
# - call: it should only be possible to run hardened command or defined functions
# - op:
#   - and
#   - or
#   - [[ ]]
# - arith
# - loop:
#   - in
#   - while
#   - for
# - switch/case
# - functions
# - on/off

def indent(level): (
  (" " * ((level + 1) * 4)) + .
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
    ) elif has("start") then (
      .start as $start | prefix + $key + " " +
        ($start.name | sanitize)
    ) elif has("stop") then (
      .stop as $stop | prefix + $key + " " +
        ($stop.name | sanitize)
    ) else (
      "runner: Unknown container task type: \"" + $key + "\"\n" | halt_error(1)
    ) end
);

def task_network_ip(prefix): (
  . as $ip |
  ($ip | keys[0]) as $key |
    if has("get") then (
      .get as $get | prefix + $key + " " +
        ($get.container | sanitize)
    ) else (
      "runner: Unknown network ip task type: \"" + $key + "\"\n" | halt_error(1)
    ) end
);

def task_network(prefix): (
  . as $network |
  ($network | keys[0]) as $key |
    if has("ip") then (
      .ip | task_network_ip(prefix + $key + " ")
    ) else (
      "runner: Unknown network task type: \"" + $key + "\"\n" | halt_error(1)
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
        ) elif has("network") then (
          .network | task_network($key + " ")
        ) else (
          "runner: Unknown task type: \"" + $key + "\"\n" | halt_error(1)
        ) end
      ] | xtrace_task(i; args; level) | map(. | indent(level))
    ) end
);

def assign(level; sanitized_value): (
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
        if (sanitized_value) then (
          $assign.value | sanitize
        ) else (
          $assign.value[0].unsanitized
        ) end | "=" + .
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

  def register(level; internal): (
    [
      foreach (.register[]) as $item (
        {
          internal: internal
        };
        . as $dot | $item | keyword($dot.internal; level + 1) as $keyword |
        {
          program: $keyword.program,
          internal: $keyword.internal
        };
        .
      )
    ]
  );

  internal as $internal |
    if has("harden") then (
      {
        program: (("harden " + (.harden | sanitize)) | indent(level)),
        internal: $internal
      }
    ) elif has("assign") then (
      . | assign(level; true) |
        {
          program: .,
          internal: $internal
        }
    ) elif has("readonly") then (
      {
        program: (("readonly " + (.readonly | sanitize)) | indent(level)),
        internal: $internal
      }
    ) elif has("if") and (.if | has("then")) then (
      . | conditional($internal; $ARGS; level) as $conditional |
        {
          program: (
            (("if " + $conditional.if.cond + "; then\n") | indent(level)) +
            $conditional.if.then + "\n" + (
              if ($conditional.else | length > 0) then (
                $conditional.else | map(
                  . as $item | $item | (
                    if (.cond | length > 0) then (
                      (("elif " + $item.cond + "; then\n") | indent(level))
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
    ) elif has("register") and has("into") then (
      . as $register | register(level; $internal) |
      {
        program: ({
          assign: $register.into,
          value: [
            {
              unsanitized: ("\"$(\n" + (map(.program) | join("\n")) + "\n" + (")\"" | indent(level)))
            }
          ]
        }  | debug| assign(level; false)),
        internal: (map(.internal) | last)
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
  0 as $level |
  .internal = {
    i: -1,
    program: (
      $ARGS.named.env + "\n\n" +
      "main ()\n{\n" +
      ("on errexit noclobber nounset pipefail lastpipe extglob\n\n" | indent($level)) +
      ("bash_setup\n\n" | indent($level)) +
      ("init\n\n" | indent($level)) +
      ("harden id\n\n" | indent($level)) +
      ("local user uid home runner_name\n" | indent($level)) +
      ("user=\"${USER:-\"$(id --user --name)\"}\"\n" | indent($level)) +
      ("uid=\"${UID:-\"$(id --user)\"}\"\n" | indent($level)) +
      ("home=\"${HOME:-\"$(printf '%s' ~)\"}\"\n" | indent($level)) +
      ("runner_name='" + $name + "'\n" | indent($level)) +
      ("readonly user uid home runner_name\n\n" | indent($level))
    )
  } |
  . as $root |
    reduce $root.run[] as $item (
      $root.internal;
      . as $internal | $item | keyword($internal; $level) as $keyword |
        {
          i: $keyword.internal.i,
          program: ($internal.program + $keyword.program + "\n")
        }
    ) | .program + "}\n\n#main \"${@}\""
);

. | main
