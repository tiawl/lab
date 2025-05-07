# !/usr/bin/env --split-string gojq --from-file

# TODO:
# - more checks like conditional "run"
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
# - on/off

{
  function: {
    user: "___",
    internal: "__"
  }
} as $PREFIX |

def indent(level): (
  (" " * ((level + 1) * 4)) + .
);

def is_legit: (
  test("^[a-zA-Z_][a-zA-Z0-9_]*$")
);

def is_reserved: (
  . as $input |
    $ARGS.named.reserved | split("\n") | any(. == $input)
);

def exit: (
  "runner: " + . + "\n" | halt_error(1)
);

def bad_varname: (
  "Bad variable name: \"" + . + "\"" | exit
);

def remove_useless_quotes: (
  gsub("\""; "'") | gsub("''"; "")
);

def sanitize: (
  def parameter_enpansion: (
    if ((has("default")) and (has("alternate"))) then (
      "You can not use \"default\" and \"alternate\" value for a same variable" | exit
    ) else . end |
    if (has("default")) then (
      ":-" + (.default[] | sanitize)
    ) elif (has("alternate")) then (
      ":+" + (.alternate[] | sanitize)
    ) else "" end
  );

  map(
    . as $input |
    if (has("literal")) then (
      "'" + .literal + "'"
    ) elif (has("char")) then (
      if (.char == "asterisk") then (
        "*"
      ) elif (.char == "tilde") then (
        "~"
      ) else (
        "Unknown char: \"" + .char + "\"" | exit
      ) end
    ) elif (has("var")) then (
      if (.var | is_legit) then (
        "\"${" + .var + (
          if ($input | has("key")) then (
            "[" + ($input.key | sanitize) + "]"
          ) else "" end
        ) + ($input | parameter_enpansion) + "}\""
      ) else (
        $input.var | bad_varname
      ) end
    ) elif (has("positional")) then (
      if (.positional | test("^[0-9]+$")) then (
        "\"${" + .positional + ($input | parameter_enpansion) + "}\""
      ) else (
        "Positional parameter only contains numeric characters" | exit
      ) end
    ) else (
      "Unknown object type: \"" + keys[0] + "\"" | exit
    ) end
  ) | join("")
);

def op: (
  def op_not: (
    op |
    {
      program: {
        before: ("! { " + .program.before),
        after: (.program.after + "; }")
      },
      yml: .yml
    }
  );

  if (type == "object") then (
    if (has("not")) then (
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
    "Unknown type: \"" + type + "\"" | exit
  ) end
);

def task_image_builder(prefix): (
  keys[0] as $key |
    if (has("prune")) then (
      .prune as $prune | prefix + $key
    ) else (
      "Unknown image builder task type: \"" + $key + "\"" | exit
    ) end
);

def task_image_tag(prefix): (
  keys[0] as $key |
    if (has("defined")) then (
      .defined as $defined | prefix + $key + " " +
        ($defined.image | sanitize) + " " +
        ($defined.tag | sanitize)
    ) elif (has("create")) then (
      .create as $create | prefix + $key + " " +
        ($create.from.image | sanitize) + " " +
        ($create.from.tag | sanitize) + " " +
        ($create.to.image | sanitize) + " " +
        ($create.to.tag | sanitize)
    ) else (
      "Unknown image tag task type: \"" + $key + "\"" | exit
    ) end
);

def task_image(prefix): (
  keys[0] as $key |
    if (has("tag")) then (
      .tag | task_image_tag(prefix + $key + " ")
    ) elif (has("builder")) then (
      .builder | task_image_builder(prefix + $key + " ")
    ) elif (has("pull")) then (
      .pull as $pull | prefix + $key + " " +
        ($pull.registry | sanitize) + " " +
        ($pull.library | sanitize) + " " +
        ($pull.image | sanitize) + " " +
        ($pull.tag | sanitize)
    ) elif (has("remove")) then (
      .remove as $remove | prefix + $key + " " +
        ($remove.image | sanitize) + " " +
        ($remove.tag | sanitize)
    ) elif (has("prune")) then (
      .prune as $prune | prefix + $key + " " +
        ($prune.matching | sanitize)
    ) elif (has("build")) then (
      .build as $build | prefix + $key + " " +
        ($build.image | sanitize) + " " +
        ($build.context | sanitize) + " " +
        ([$build.args[][] | sanitize] | join(" "))
    ) else (
      "Unknown image task type: \"" + $key + "\"" | exit
    ) end
);

def task_container_resource(prefix): (
  keys[0] as $key |
    if (has("copy")) then (
      .copy as $copy | prefix + $key + " " +
      ($copy.name | sanitize) + " " +
      ($copy.src | sanitize) + " " +
      ($copy.dest | sanitize)
    ) else (
      "Unknown container resource task type: \"" + $key + "\"" | exit
    ) end
);

def task_container(prefix): (
  keys[0] as $key |
    if (has("resource")) then (
      .resource | task_container_resource(prefix + $key + " ")
    ) elif (has("create")) then (
      .create as $create | prefix + $key + " " +
        ($create.name | sanitize) + " " +
        ($create.image | sanitize) + " " +
        ($create.hostname | sanitize)
    ) elif (has("start")) then (
      .start as $start | prefix + $key + " " +
        ($start.name | sanitize)
    ) elif (has("stop")) then (
      .stop as $stop | prefix + $key + " " +
        ($stop.name | sanitize)
    ) else (
      "Unknown container task type: \"" + $key + "\"" | exit
    ) end
);

def task_network_ip(prefix): (
  keys[0] as $key |
    if (has("get")) then (
      .get as $get | prefix + $key + " " +
        ($get.container | sanitize)
    ) else (
      "Unknown network ip task type: \"" + $key + "\"" | exit
    ) end
);

def task_network(prefix): (
  keys[0] as $key |
    if (has("ip")) then (
      .ip | task_network_ip(prefix + $key + " ")
    ) else (
      "Unknown network task type: \"" + $key + "\"" | exit
    ) end
);

def task_call(is_internal): (
  . as $input |
    if (is_internal) then (
      (.call + " " + (.args | map(sanitize) | join(" "))) | remove_useless_quotes
    ) else (
      $PREFIX.function.internal + "call \"" + (($PREFIX.function.user + .call + " " + (.args | map(sanitize) | join(" "))) | remove_useless_quotes) + "\""
    ) end
);

def task_print: (
  "printf '" + .print + "' " + (.args | map(sanitize) | join(" "))
);

def task_on_off: (
  (keys[0]) + " " + (values[] | map(sanitize) | join(" "))
);

def xtrace_task(is_internal): (
  if (is_internal) then (
    [
      .program
    ]
  ) else (
    [
      $PREFIX.function.internal + "xtrace \"" + (.xtrace | remove_useless_quotes) + "\"",
      .program
    ]
  ) end
);

def task(level; is_internal): (
  if (isempty(.[])) then (
    []
  ) else (
    keys[0] as $key |
    if (has("image")) then (
      .image | task_image($key + " ") as $program |
      {
        program: $program,
        xtrace: $program
      }
    ) elif (has("container")) then (
      .container | task_container($key + " ") as $program |
      {
        program: $program,
        xtrace: $program
      }
    ) elif (has("network")) then (
      .network | task_network($key + " ") as $program |
      {
        program: $program,
        xtrace: $program
      }
    ) elif (has("call")) then (
      {
        program: task_call(is_internal),
        xtrace: (.call + " " + (.args | map(sanitize) | join(" ")))
      }
    ) elif (has("print")) then (
      task_print as $program |
      {
        program: $program,
        xtrace: $program
      }
    ) elif ((has("on")) or (has("off"))) then (
      task_on_off as $program |
      {
        program: $program,
        xtrace: $program
      }
    ) else (
      "Unknown task type: \"" + $key + "\"" | exit
    ) end | xtrace_task(is_internal) | map(indent(level))
  ) end
);

def harden(level; is_internal): (
  (
    "harden " + (.harden | sanitize)+ (
      if (has("as")) then (
        .as |
          if (is_reserved) then (
            "You can not use a reserved BASH word to harden a command:" + ($ARGS.named.reserved | gsub("\n"; " ")) | exit
          ) elif (is_legit) then (
            " " + (
              if (is_internal | not) then (
                $PREFIX.function.user
              ) else "" end
            ) + .
          ) else (
            bad_varname
          ) end
      ) elif (is_internal | not) then (
        " '" + $PREFIX.function.user + "'" + (.harden | sanitize) | gsub("''"; "")
      ) else "" end
    )
  ) | indent(level)
);

def default_assign: (
  if ((.type == "") or (.type == null)) then (
    .type = "string"
  ) else . end |
  if ((.scope == "") or (.scope == null)) then (
    .scope = "local"
  ) else . end
);

def assign(level; sanitized_value): (
  default_assign |
  if ((has("key")) and (.type != "string")) then (
    "Values into associative or indexed array must be string typed" | exit
  ) else . end |
  if ((has("key")) and (has("value")) and (.value | length > 1)) then (
    "You can not attribute several values to a single key" | exit
  ) else . end |
  if ((.type == "string") and (has("value")) and (.value | length > 1)) then (
    "You can not attribute several values to a string variable" | exit
  ) else . end | . as $input |
  (
    if (.scope == "global") then (
      "global "
    ) elif (.scope == "local") then (
      "local "
    ) else (
      "Unknown assign.scope: \"" + .type + "\"" | exit
    ) end
  ) + (
    if (.type == "string") then (
      ""
    ) elif (.type == "associative") then (
      "-A "
    ) elif (.type == "indexed") then (
      "-a "
    ) elif (.type == "reference") then (
      "-n "
    ) else (
      "Unknown assign.type: \"" + .type + "\"" | exit
    ) end
  ) + (.assign | sanitize) + (
    if (has("key")) then (
      "[" + (.key | sanitize) + "]"
    ) else "" end
  ) + (
    if (has("value")) then (
      .value[] |
        if (sanitized_value) then (
          sanitize |
          if (($input.type == "indexed") or ($input.type == "associative")) then (
            "( " + . + " )"
          ) else . end
        ) else (
          .[0].unsanitized
        ) end | "=" + .
    ) else "" end
  ) | indent(level)
);

def readonly(level): (
  ("readonly " + (.readonly | map(sanitize) | join(" "))) | indent(level)
);

def defer(level; is_internal): (
  .defer |
  ((keys[0] | if (test("^container$|^image$|^network$|^volume$|^runner$")) then "s" else "" end) + "defer") as $fn |
  task(-1; is_internal) | map(
    gsub("'"; "'\"'\"'") | (
      if (startswith($PREFIX.function.internal + "xtrace")) then (
        "defer '"
      ) else (
        $fn + " '"
      ) end
    ) + . + "'" | indent(level)
  ) | join("\n")
);

def define(level; is_internal): (
  def block(level; is_internal): (
    def conditional(level; is_internal): (
      def conditional_inner(level; is_internal): (
        # check "run" field is an array
        if ((.run | type) != "array") then (
          "Conditional \"run\" field must an array type but it is \"" + (.run | type) + "\"" | exit
        ) else . end |

        . as $input |
          # "else" case
          if ($input | ((type == "object") and (keys | length == 1) and (keys[0] == "run"))) then (
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
              op: ($input | op),
            }
          ) end |
          .op as $op |
          ([
            {
              run: ($input | .run[] | block(level + 1; is_internal))
            }
          ]) |
            {
              cond: ($op.program.before + ($op.yml | task(-1; is_internal) | join("; ")) + $op.program.after),
              run: (map(.run) | join("\n")),
            }
      );

      . as $input |
      if (.if | has("run") | not) then (
        ".if used without .if.run" | exit
      ) else . end |
      ($input.if | conditional_inner(level; is_internal)) as $if |
      {
        if: $if,
        else: []
      } as $output |
        $input |
        if (has("else")) then (
          $output | setpath(["else"]; .else + [
            $input.else[] | conditional_inner(level; is_internal)
          ])
        ) else (
          $output
        ) end |
        (("if " + .if.cond + "; then\n") | indent(level)) +
        .if.run + "\n" + (
          if (.else | length > 0) then (
            .else | map(
              (
                if (.cond | length > 0) then (
                  (("elif " + .cond + "; then\n") | indent(level))
                ) else (
                  "else\n" | indent(level)
                ) end
              ) + .run
            ) | join("\n") + "\n"
          ) else "" end
        ) + ("fi" | indent(level))
    );

    def register(level; is_internal): (
      . as $input |
      (if (is_internal) then 0 else 1 end) as $offset |
        if (. | has("into") | not) then (
          ".register used without .into" | exit
        ) else . end |
        .register[] | block(level + $offset + 1; is_internal) |
        {
          assign: $input.into,
          value: [
            [
              {
                unsanitized: ("\"$(\n" + . + "\n" + (
                  if (is_internal | not) then (
                    "declare -f " + $PREFIX.function.internal + "autoincr >&3\n" | indent(level + $offset + 1)
                  ) else "" end
                ) + (")\"" | indent(level + $offset)))
              }
            ]
          ]
        } | assign(level + $offset; false) |
        if (is_internal | not) then (
          ("coproc CAT { cat; }\n" | indent(level)) +
          ("{\n" | indent(level)) + . + "\n" +
          ("} 3>&${CAT[1]}\n" | indent(level)) +
          ("exec {CAT[1]}>&-\n" | indent(level)) +
          ("mapfile source_me <&${CAT[0]}\n" | indent(level)) +
          ("source /proc/self/fd/0 <<< \"${source_me[@]}\"\n" | indent(level)) +
          ("unset source_me\n" | indent(level))
        ) else . end
    );

    if (has("harden")) then (
      harden(level; is_internal)
    ) elif (has("assign")) then (
      assign(level; true)
    ) elif (has("define")) then (
      define(level; is_internal)
    ) elif (has("readonly")) then (
      readonly(level)
    ) elif (has("if")) then (
      conditional(level; is_internal)
    ) elif (has("defer")) then (
      defer(level; is_internal)
    ) elif (has("register")) then (
      register(level; is_internal)
    ) elif (has("initialized")) then (
      false
    ) else (
      task(level; is_internal) | join("\n")
    ) end
  );

  .define |
    if (.name | is_reserved) then (
      "You can not define a function with a reserved BASH word:" + ($ARGS.named.reserved | gsub("\n"; " ")) | exit
    ) elif (.name | is_legit | not) then (
      .name | bad_varname
    ) else . end | ((
    if (is_internal) then (
      $PREFIX.function.internal
    ) else (
      $PREFIX.function.user
    ) end + .name + " ()\n") | indent(level)) + (
    "{\n" | indent(level)) + (
    [
      foreach .run[] as $item (
        {
          is_internal: is_internal
        };
        . as $input |
        ($item | block(level + 1; $input.is_internal)) as $output |
        if ($output | type == "string") then (
          {
            is_internal: $input.is_internal,
            extract: $output
          }
        ) elif ($output | type == "boolean") then (
          {
            is_internal: $output,
            extract: ""
          }
        ) end;
        .extract as $extract |
        if ($extract | length == 0) then empty else $extract end
      )
    ] | join("\n")) + "\n" + (
    "}\n" | indent(level))
);

def main: (
  # TODO: 1 level is enough
  -1 as $level |
    . as $input |
    {
      define: {
        name: "main",
        run: (
          [
            {call: ($PREFIX.function.internal + "init"), args: []},
            {harden: [{literal: "id"}]},
            {register: [{call: "id", args: [[{literal: "--user"}], [{literal: "--name"}]]}], into: [{literal: "user"}]},
            {assign: [{literal: "user"}], value: [[{var: "USER", default: [[{var: "user"}]]}]]},
            {register: [{call: "id", args: [[{literal: "--user"}]]}], into: [{literal: "uid"}]},
            {assign: [{literal: "uid"}], value: [[{var: "UID", default: [[{var: "uid"}]]}]]},
            {register: [{print: "%s", args: [[{char: "tilde"}]]}], into: [{literal: "home"}]},
            {assign: [{literal: "home"}], value: [[{var: "HOME", default: [[{var: "home"}]]}]]},
            {assign: [{literal: "runner_name"}], value: [[{literal: (input_filename | sub(".*/";"") | sub("\\.yml$";""))}]]},
            {readonly: [[{literal: "user"}], [{literal: "uid"}], [{literal: "home"}], [{literal: "runner_name"}]]},
            {initialized: true}
          ] + $input.run
        )
      }
    } | define($level; true)
);

def internals: (
  # TODO: 1 level is enough
  -1 as $level |
    [
      {
        define: {
          name: "init",
          run: (
            [
              {on: [[{literal: "errexit"}], [{literal: "errtrace"}], [{literal: "noclobber"}], [{literal: "nounset"}], [{literal: "pipefail"}], [{literal: "lastpipe"}], [{literal: "extglob"}]]},
              {call: ("bash_setup"), args: []},
              {call: ("load_ressources"), args: []},
              {call: ("init"), args: []}
            ]
          )
        }
      }
    ] | map(define($level; true)) | join("\n")
    # TODO:
    #{
    #  name: "call2",
    #  run: [
    #    {call: "capture", args: []},
    #    {on: [[{literal: "noglob"}]]},
    #    {
    #      into: "authorized",
    #      register: {call: "compgen", args: [[{literal: "-A"}], [{literal: "function"}], [{literal: "-A"}], [{literal: "enabled"}]]}
    #    },
    #    {call: "set", args: [[{literal: "--"}], [{var: "authorized"}], [{literal: "|"}], [{var: "1"}]]},
    #    {call: "restore", args: []}
    #  ]
    #} | define($level; $PREFIX.function.internal) as $__call | $output
);

def yml2bash: (
  0 as $level |
    $ARGS.named.env + "\n" +
    $PREFIX.function.internal + "call ()\n" +
    "{\n" +
    ("capture\n" | indent($level)) +
    ("on noglob\n" | indent($level)) +
    ("set -- \"$(compgen -A function -X '!" + $PREFIX.function.user + "*')\" '|' \"${1}\"\n" | indent($level)) +
    ("restore\n" | indent($level)) +
    ("case \"${2}${1//$'\\n'/\"${2}\"}${2}\" in\n" | indent($level)) +
    ("( *\"${2}${3%% *}${2}\"* ) : ;;\n" | indent($level)) +
    ("( * ) printf 'Unknown \"%s\". You probably forgot to harden a command, to define a function or to enable a disabled builtin\\n' \"${3}\" >&2; return 1 ;;\n" | indent($level)) +
    ("esac\n" | indent($level)) +
    ("source <(printf '%s' \"${3}\")\n" | indent($level)) +
    "}\n" +
    $PREFIX.function.internal + "autoincr ()\n" +
    "{\n" +
    ("REPLY=1\n" | indent($level)) +
    ("source /proc/self/fd/0 <<< \"$(declare -f \"${FUNCNAME[0]}\" | sed \"${sed[autoincr]}\")\"\n" | indent($level)) +
    "}\n" +
    $PREFIX.function.internal + "color ()\n" +
    "{\n" +
    ("set -- \"$(( (${1} % " + ($ARGS.positional | length | tostring) + ") + 2 ))\" " + ($ARGS.positional | join(" ")) + "\n" | indent($level)) +
    ("REPLY=\"${!1}\"\n" | indent($level)) +
    "}\n" +
    $PREFIX.function.internal + "xtrace ()\n" +
    "{\n" +
    ($PREFIX.function.internal + "autoincr\n" | indent($level)) +
    ("set -- \"${1}\" \"${REPLY}\"\n" | indent($level)) +
    ($PREFIX.function.internal + "color \"${2}\"\n" | indent($level)) +
    ("set -- \"${1}\" \"${2}\" \"${REPLY}\"\n" | indent($level)) +
    ("printf '%b\\033[1m%s\\033[0m > %s\\n' \"\\033[38;5;${3}m\" \"${2}\" \"${1}\" >&2\n" | indent($level)) +
    "}\n" +
    internals +
    main +
    $PREFIX.function.internal + "main \"${@}\""
);

yml2bash
