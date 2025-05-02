# !/usr/bin/env --split-string gojq --from-file

# TODO:
# - more checks like conditional "then"
# - op:
#   - and
#   - or
#   - [[ ]]
# - arith
# - loop:
#   - in:     for <name> [ [ in [ <word> ... ] ] ; ] do <list>; done
#   - while:  while list-1; do list-2; done
#             while [[ expression ]]; do list-2; done
#   - for:    for (( <expr1> ; <expr2> ; <expr3> )) ; do <list> ; done
# - switch/case
# - functions
# - on/off

def indent(level): (
  (" " * ((level + 1) * 4)) + .
);

def is_authorized_varname: (
  test("^[a-zA-Z_][a-zA-Z0-9_]*$")
);

def bad_varname: (
  "runner: Bad variable name: \"" + . + "\"\n" | halt_error(1)
);

def sanitize: (
  map(
    if has("literal") then (
      "'" + .literal + "'"
    ) elif has("var") then (
      . as $var |
        if ($var.var | is_authorized_varname) then (
          "\"${" + $var.var + (if ($var | has("key")) then ("[" + ($var.key | sanitize) + "]") else "" end) + "}\""
        ) else (
          $var.var | bad_varname
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
        ([$build.args[][] | sanitize] | join(" "))
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

def remove_useless_quotes: (
  gsub("\""; "'") | gsub("''"; "")
);

def xtrace_task: (
  [
    "__xtrace \"" + (.xtrace | remove_useless_quotes) + "\""
  ] + .program
);

def task(level): (
  . as $task |
    if $task | isempty(.[]) then (
      []
    ) else (
      ($task | keys[0]) as $key |
      if has("image") then (
        .image | task_image($key + " ") as $program |
        {
          program: [$program],
          xtrace: $program
        }
      ) elif has("container") then (
        .container | task_container($key + " ") as $program |
        {
          program: [$program],
          xtrace: $program
        }
      ) elif has("network") then (
        .network | task_network($key + " ") as $program |
        {
          program: [$program],
          xtrace: $program
        }
      ) elif has("call") then (
        . as $call |
        if (.call | is_authorized_varname | not) then (
          "runner: Bad called function name: \"" + .call + "\"\n" | halt_error(1)
        ) else . end |
        (.call + " " + (.args | map(sanitize) | join(" "))) as $program |
        {
          program: [
            "on noglob",
            "set -- \"$(compgen -A function)\" '|' " + $call.call + " \"${@}\"",
            "off noglob",
            "case \"${2}${1//$'\\n'/\"${2}\"}${2}\" in",
            "( *\"${2}${3}${2}\"* ) : ;;",
            "( * ) printf 'You can not call an unhardened command or an undefined function\\n' >&2; return 1 ;;",
            "esac",
            "shift 3",
            "eval \"" + ($program | remove_useless_quotes) + "\""
          ],
          xtrace: $program
        }
      ) else (
        "runner: Unknown task type: \"" + $key + "\"\n" | halt_error(1)
      ) end | xtrace_task | map(. | indent(level))
    ) end
);

# TODO; assign a list: "local -a list=()"
def assign(level; sanitized_value): (
  (
    if (.scope == "global") then (
      "global "
    ) elif (.scope == "local" or .scope == "" or .scope == null) then (
      "local "
    ) end
  ) + (
    if (.type == "string" or .type == "" or .type == null) then (
      ""
    ) elif (.type == "map") then (
      "-A "
    ) elif (.type == "array") then (
      "-a "
    ) elif (.type == "ref") then (
      "-n"
    ) else (
      "runner: Unknown assign.type: \"" + .type + "\"\n" | halt_error(1)
    ) end
  ) + (.assign | sanitize) + (
    if has("key") then (
      "[" + (.key | sanitize) + "]"
    ) else "" end
  ) + (
    if has("value") then (
      if (sanitized_value) then (
        .value | sanitize
      ) else (
        .value[0].unsanitized
      ) end | "=" + .
    ) else "" end
  ) | indent(level)
);

def keyword(level): (
  def conditional(level): (
    def conditional_inner(level): (
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
          }
        # "if" and "elif" case
        ) else (
          {
            op: ($inner | op),
          }
        ) end |
        .op as $op |
        ([
          $inner | .then[] | keyword(level + 1) |
          {
            then: .program,
          }
        ]) |
          {
            cond: ($op.program.before + ($op.yml | task(-1) | join("; ")) + $op.program.after),
            then: (map(.then) | join("\n")),
          }
    );

    . as $conditional |
    ($conditional.if | conditional_inner(level) | .) as $if |
    {
      if: $if,
      else: []
    } as $return |
      $conditional |
      if has("else") then (
        $return | setpath(["else"]; .else + [
          $conditional.else[] | conditional_inner(level)
        ])
      ) else (
        $return
      ) end
  );

  def register(level): (
    [
      .register[] | keyword(level + 1) |
      {
        program: .program
      }
    ]
  );

  if has("harden") then (
    {
      program: (("harden " + (.harden | sanitize) + (
        if has("as") then (
          if (.as | is_authorized_varname) then (
            " " + .as
          ) else (
            .as | bad_varname
          ) end
        ) else "" end)
      ) | indent(level))
    }
  ) elif has("assign") then (
    . | assign(level; true) |
      {
        program: .,
      }
  ) elif has("readonly") then (
    {
      program: (("readonly " + (.readonly | sanitize)) | indent(level)),
    }
  ) elif has("if") and (.if | has("then")) then (
    . | conditional(level) as $conditional |
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
        )
      }
  ) elif has("defer") then (
    {
      program: (.defer | task(level) | map(gsub("'"; "'\"'\"'") | sub("^(?<match>[[:space:]]*)"; "\(.match)defer '") | sub("$"; "'")) | join("\n")),
    }
  ) elif has("register") and has("into") then (
    . as $register | register(level + 1) |
    {
      program: (
        {
          assign: $register.into,
          value: [
            {
              unsanitized: ("\"$(\n" + (map(.program) | join("\n")) + "\n" + ("declare -f __autoincr >&3\n" | indent(level + 2)) + (")\"\n" | indent(level + 1)))
            }
          ],
        } | assign(level + 1; false) |
        ("coproc CAT { cat; }\n" | indent(level)) +
        ("{\n" | indent(level)) + . +
        ("} 3>&${CAT[1]}\n" | indent(level)) +
        ("exec {CAT[1]}>&-\n" | indent(level)) +
        ("eval \"$(cat <&${CAT[0]})\"\n" | indent(level))
      )
    }
  ) else (
    {
      program: (. | task(level) | join("\n")),
    }
  ) end
);

def main: (
  (input_filename | sub(".*/";"") | sub("\\.yml$";"")) as $name |
  0 as $level |
    $ARGS.named.env + "\n\n" +
    "__autoincr () {\n" +
    ("REPLY=1\n" | indent($level)) +
    ("eval \"$(declare -f \"${FUNCNAME[0]}\" | sed '/^\\s\\+REPLY=[0-9]\\+;$/ { s/;$//; :d; s/9\\(_*\\)$/_\\1/; td; s/=\\(_*\\)$/=1\\1/; tn; s/8\\(_*\\)$/9\\1/; tn; s/7\\(_*\\)$/8\\1/; tn; s/6\\(_*\\)$/7\\1/; tn;s/5\\(_*\\)$/6\\1/; tn; s/4\\(_*\\)$/5\\1/; tn; s/3\\(_*\\)$/4\\1/; tn; s/2\\(_*\\)$/3\\1/; tn; s/1\\(_*\\)$/2\\1/; tn; s/0\\(_*\\)$/1\\1/; tn; :n; y/_/0/; s/$/;/ }')\"\n" | indent($level)) +
    "}\n\n" +
    "__color () {\n" +
    ("set -- \"$(( (${1} % " + ($ARGS.positional | length | tostring) + ") + 2 ))\" " + ($ARGS.positional | join(" ")) + "\n" | indent($level)) +
    ("REPLY=\"${!1}\"\n" | indent($level)) +
    "}\n\n" +
    "__xtrace () {\n" +
    ("__autoincr\n" | indent($level)) +
    ("set -- \"${1}\" \"${REPLY}\"\n" | indent($level)) +
    ("__color \"${2}\"\n" | indent($level)) +
    ("set -- \"${1}\" \"${2}\" \"${REPLY}\"\n" | indent($level)) +
    ("printf '%b\\033[1m%s\\033[0m > %s\\n' \"\\033[38;5;${3}m\" \"${2}\" \"${1}\" >&2\n" | indent($level)) +
    "}\n\n" +
    "main ()\n{\n" +
    ("on errexit noclobber nounset pipefail lastpipe extglob\n\n" | indent($level)) +
    ("bash_setup\n\n" | indent($level)) +
    ("load_ressources\n\n" | indent($level)) +
    ("init\n\n" | indent($level)) +
    ("harden id\n\n" | indent($level)) +
    ("local user uid home runner_name\n" | indent($level)) +
    ("user=\"${USER:-\"$(id --user --name)\"}\"\n" | indent($level)) +
    ("uid=\"${UID:-\"$(id --user)\"}\"\n" | indent($level)) +
    ("home=\"${HOME:-\"$(printf '%s' ~)\"}\"\n" | indent($level)) +
    ("runner_name='" + $name + "'\n" | indent($level)) +
    ("readonly user uid home runner_name\n\n" | indent($level)) +
    ([.run[] | keyword($level)] | map(.program) | join("\n")) +
    "\n}\n\nmain \"${@}\""
);

. | main
