# !/usr/bin/env --split-string gojq --from-file

# TODO:
# - more checks like conditional "run"
# - op:
#   - and
#   - or
#   - [[ ]]
# - loop:
#   - in:     for <name> [ [ in [ <word> ... ] ] ; ] do <list>; done
#   - while:  while list-1; do list-2; done
#             while [[ expression ]]; do list-2; done
#   - for:    for (( <expr1> ; <expr2> ; <expr3> )) ; do <list> ; done

{
  function: {
    user: "___",
    internal: "__"
  }
} as $PREFIX |
{
  internal: -1,
  quiet: 0,
  user: 1
} as $MODE |

def indent(level): (
  (" " * ((level + 1) * 4)) + .
);

def is_legit: (
  test("^[a-zA-Z_][a-zA-Z0-9_]*$")
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

def among(k): (
  . as $input |
    reduce k[] as $item (0; . + ($input | if has($item) then 1 else 0 end))
);

def is_unique_key_object: (
  if (type != "object") then (
    "Expected an object: " + (. | tostring) | exit
  ) else . end |

  if (keys | length > 1) then (
    "This object must contain a unique key: " + (. | tostring) | exit
  ) else . end
);

def sanitize: (
  def expansion: (
    if (among(["default", "alternate", "replace"]) == 2) then (
      "You can only use one of \"default\", \"alternate\" or \"replace\" fields for a same variable" | exit
    ) else . end |
    if (has("default")) then (
      ":-" + (.default | sanitize)
    ) elif (has("alternate")) then (
      ":+" + (.alternate | sanitize)
    ) elif (has("replace")) then (
      .replace |
        if (has("all")) then (
          "//" + (.all | sanitize) + (if (has("with")) then ("/" + (.with | sanitize)) else "" end)
        ) elif (has("first")) then (
          "/" + (.first | sanitize) + (if (has("with")) then ("/" + (.with | sanitize)) else "" end)
        ) elif (has("start") and (.match == "shortest")) then (
          "#" + (.start | sanitize)
        ) elif (has("start") and (.match == "longest")) then (
          "##" + (.start | sanitize)
        ) elif (has("end") and (.match == "shortest")) then (
          "%" + (.end | sanitize)
        ) elif (has("end") and (.match == "longest")) then (
          "%%" + (.end | sanitize)
        ) else (
          "Unknown field into \"replace\": " + (. | tostring) | exit
        ) end
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
      ) elif (.char == "newline") then (
        "$'\\n'"
      ) else (
        "Unknown char: \"" + .char + "\"" | exit
      ) end
    ) elif (has("var")) then (
      if (.var | is_legit) then (
        "\"${" + .var + (
          if ($input | has("key")) then (
            "[" + ($input.key | sanitize) + "]"
          ) elif ($input | has("index")) then (
            if ($input.index | type == "number") then (
              "[" + ($input.index | tostring) + "]"
            ) else (
              "The .var.index must be number typed" | exit
            ) end
          ) else "" end
        ) + ($input | expansion) + "}\""
      ) else (
        $input.var | bad_varname
      ) end
    ) elif (has("parameter")) then (
      if (.parameter | type == "number") then (
        "\"${" + (.parameter | tostring) + ($input | expansion) + "}\""
      ) else (
        "Positional parameter must be number typed" | exit
      ) end
    ) else (
      "Unknown field object passing through sanitize(): \"" + keys[0] + "\"" | exit
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
    "Only object JSON type are authorized through op(): \"" + type + "\"" | exit
  ) end
);

def xtrace(mode): (
  if (mode == $MODE.user) then (
    [
      $PREFIX.function.internal + "xtrace \"" + (.xtrace | remove_useless_quotes) + "\"",
      .program
    ]
  ) else (
    [
      .program
    ]
  ) end
);

def orchestrator: {
  image: {
    builder: {
      prune: (try (
        .image.builder.prune as $prune |
          if $prune then "image builder prune" else null end
      ) catch null)
    },
    tag: {
      defined: (try (
        .image.tag.defined as $defined |
          if $defined then (
            "image tag defined " +
              ($defined.image | sanitize) + " " +
              ($defined.tag | sanitize)
          ) else null end
      ) catch null),
      create: (try (
        .image.tag.create as $create |
          if $create then (
            "image tag create " +
              ($create.from.image | sanitize) + " " +
              ($create.from.tag | sanitize) + " " +
              ($create.to.image | sanitize) + " " +
              ($create.to.tag | sanitize)
          ) else null end
      ) catch null)
    },
    pull: (try (
      .image.pull as $pull |
        if $pull then (
          "image pull " +
            ($pull.registry | sanitize) + " " +
            ($pull.library | sanitize) + " " +
            ($pull.image | sanitize) + " " +
            ($pull.tag | sanitize)
        ) else null end
    ) catch null),
    remove: (try (
      .image.remove as $remove |
        if $remove then (
          "image remove " +
            ($remove.image | sanitize) + " " +
            ($remove.tag | sanitize)
        ) else null end
    ) catch null),
    prune: (try (
      .image.prune as $prune |
        if $prune then (
          "image prune " +
            ($prune.matching | sanitize)
        ) else null end
    ) catch null),
    build: (try (
      .image.build as $build |
        if $build then (
          "image build " +
            ($build.image | sanitize) + " " +
            ($build.context | sanitize) + " " +
            ([$build.args[][] | sanitize] | join(" "))
        ) else null end
    ) catch null)
  },
  container: {
    resource: {
      copy: (try (
        .container.resource.copy as $copy |
          if $copy then (
            "container resource copy " +
              ($copy.name | sanitize) + " " +
              ($copy.src | sanitize) + " " +
              ($copy.dest | sanitize)
          ) else null end
      ) catch null)
    },
    create: (try (
      .container.create as $create |
        if $create then (
          "container create " +
            ($create.name | sanitize) + " " +
            ($create.image | sanitize) + " " +
            ($create.hostname | sanitize)
        ) else null end
    ) catch null),
    start: (try (
      .container.start as $start |
        if $start then (
          "container start " +
            ($start.name | sanitize)
        ) else null end
    ) catch null),
    stop: (try (
      .container.stop as $stop |
        if $stop then (
          "container stop " +
            ($stop.name | sanitize)
        ) else null end
    ) catch null)
  },
  network: {
    ip: {
      get: (try (
        .network.ip.get as $get |
          if $get then (
            "network ip get " +
              ($get.container | sanitize)
          ) else null end
      ) catch null)
    }
  }
};

def harden(level; mode): (
  (
    .harden |
    "harden " + (.command | sanitize) + (
      if (has("as") and (.as | length > 0)) then (
        " " + (
          if (mode != $MODE.internal) then (
            $PREFIX.function.user
          ) else "" end
        ) + (.as | sanitize)
      ) elif (mode != $MODE.internal) then (
        " '" + $PREFIX.function.user + "'" + (.command | sanitize) | gsub("''"; "")
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
  .assign | default_assign |
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
      "Unknown .assign.scope: \"" + .type + "\"" | exit
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
      "Unknown .assign.type: \"" + .type + "\"" | exit
    ) end
  ) + (.name | sanitize) + (
    if (has("key")) then (
      "[" + (.key | sanitize) + "]"
    ) else "" end
  ) + (
    if (has("value")) then (
      if (sanitized_value) then (
        if (($input.type == "indexed") or ($input.type == "associative")) then (
          ("'('" + (.value | map(sanitize) | join("' '")) + "')'") | gsub("''"; "")
        ) else (
          .value[0] | sanitize
        ) end
      ) else (
        .value[][0].unsanitized
      ) end | "=" + .
    ) else "" end
  ) | indent(level)
);

def readonly(level): (
  ("readonly " + (.readonly | map(sanitize) | join(" "))) | indent(level)
);

def print(level): (
  (
    .print |
    "printf " + (
      if (has("var")) then (
        if (.var | is_legit) then (
          "-v " + .var + " "
        ) else (
          .var | bad_varname
        ) end
      ) else "" end
    ) + "'" + .format + "' " + (.args | map(sanitize) | join(" ")) + (
      if (has("to")) then (
        if (.to == "stderr") then (
          " >&2"
        ) else (
          " >> " + .to
        ) end
      ) else "" end
    )
  ) | indent(level)
);

def return(level): (
  ("return " + (.return | tostring)) | indent(level)
);

def skip(level): (
  (": " + (.skip | map(sanitize) | join(" "))) | indent(level)
);

def on_off(level): (
  ((keys[0]) + " " + (values[] | map(sanitize) | join(" "))) | indent(level)
);

def capture_restore(level): (
  if (.capture or .restore) then (keys[0] | indent(level)) else "" end
);

def parameters(level): (
  ("set -- " + (.parameters | map(sanitize) | join(" "))) | indent(level)
);

def arithmetic(level): (
  def arithmetic_inner: (
    def arithmetic_op: (
      if (.op == "add") then (
        "+"
      ) elif (.op == "modulo") then (
        "%"
      ) else (
        "Unknown arithmetic operand: " + . | exit
      ) end
    );

    def arithmetic_side: (
      is_unique_key_object |

      if ((has("parameter")) or (has("var"))) then (
        [.] | sanitize
      ) elif (has("number")) then (
        if (.number | type == "number") then (
          .number | tostring
        ) else (
          ".number arithmetic side must be number typed" | exit
        ) end
      ) elif (has("arithmetic")) then (
        .arithmetic | arithmetic_inner
      ) else (
        "Unknown arithmetic side: " + (. | tostring) | exit
      ) end
    );

    "( " + (.left | arithmetic_side) + " " + (arithmetic_op) + " " + (.right | arithmetic_side) + " )"
  );

  ("(" + (.arithmetic | arithmetic_inner) + ")") | indent(level)
);

def define(level; mode): (
  def group(level; mode): (
    def command(level; mode): (
      def switch(level; mode): (
        .switch as $input | .switch |
          ("case " + (.evaluate | sanitize) + " in\n") | indent(level) + (
            $input.branches | map(
              . as $branch |
              ("( " + ($branch.pattern | sanitize) + " ) ") | indent(level) +
              ($branch | group(level; mode)) + " ;;\n"
            ) | join("")
          ) + ("esac" | indent(level))
      );

      def raw(level; mode): (
        .raw |
          if (mode == $MODE.internal) then (
            (.command + " " + (.args | map(sanitize) | join(" ")) + (
              if (has("pipe")) then (
                " | " + (.pipe | command(-1; mode))
              ) else "" end
            )) | indent(level)
          ) else (
            "\"raw\" can only be used as internal user" | exit
          ) end
      );

      def call(mode): (
        .call |
          $PREFIX.function.internal + "call \"" + (($PREFIX.function.user + .command + " " + (.args | map(sanitize) | join(" "))) | remove_useless_quotes) + (
            if (has("pipe")) then (
              " | " + (.pipe | command(-1; mode))
            ) else "" end
          ) + "\""
      );

      def traceable(level; mode): (
        if (isempty(.[])) then (
          []
        ) else (
          . as $input | ((
            orchestrator |
              walk(
                if (type == "object") then (
                  with_entries(select((.value != null) and (.value | (type == "object" and length == 0) | not)))
                ) else . end
              ) | .. | select(type == "string")
            ) // null) as $program |
          if ($program | type == "string") then (
            {
              program: $program,
              xtrace: $program
            }
          ) elif ($input | has("call")) then (
            {
              program: ($input | call(mode)),
              xtrace: ($input.call.command + " " + ($input.call.args | map(sanitize) | join(" ")))
            }
          ) else (
            "Unknown traceable type: \"" + ($input | tostring) + "\"" | exit
          ) end | xtrace(mode) | map(indent(level))
        ) end
      );

      def deferrable(level; mode): (
        traceable(level; mode)
      );

      def defer(level; mode): (
        .defer |
        ((keys[0] | if (test("^container$|^image$|^network$|^volume$|^runner$")) then "s" else "" end) + "defer") as $fn |
        deferrable(-1; mode) | map(
          gsub("'"; "'\"'\"'") | (
            if (startswith($PREFIX.function.internal + "xtrace")) then (
              "defer '"
            ) else (
              $fn + " '"
            ) end
          ) + . + "'" | indent(level)
        ) | join("\n")
      );

      def conditionable(level; mode): (
        traceable(level; mode)
      );

      def conditional(level; mode): (
        def conditional_inner(level; mode): (
          # check "group" field is an array
          if ((.group | type) != "array") then (
            "Conditional \"group\" field must be an array type but it is \"" + (.group | type) + "\"" | exit
          ) else . end |

          . as $input |
            # "else" case
            if ((type == "object") and (keys | length == 1) and (keys[0] == "group")) then (
              {
                op: {
                  program: {
                    before: "",
                    after: ""
                  },
                  yml: {}
                },
              }
            # "if" and "elif" cases
            ) else (
              {
                op: ($input | op),
              }
            ) end | .op as $op |
              {
                cond: ($op.program.before + ($op.yml | conditionable(-1; mode) | join("; ")) + $op.program.after),
                group: ($input | group(level; mode)),
              }
        );

        .if | . as $input |
        if (has("group") | not) then (
          ".if used without .if.group" | exit
        ) else . end |
        {
          if: conditional_inner(level; mode),
          else: []
        } as $output | $input |
          if (has("else")) then (
            $output | setpath(["else"]; .else + [
              $input.else[] | conditional_inner(level; mode)
            ])
          ) else (
            $output
          ) end |
          (("if " + .if.cond + "; then ") | indent(level)) +
          .if.group + (
            if (.else | length > 0) then (
              .else | map(
                (
                  if (.cond | length > 0) then (
                    " elif " + .cond + "; then "
                  ) else (
                    " else "
                  ) end
                ) + .group
              ) | join("")
            ) else "" end
          ) + " fi"
      );

      def sourceable(mode): (
        if (has("call")) then call(mode)
        elif (has("print")) then print(-1)
        else ("Authorized tasks into source.from JSON array are \"call\" and \"print\"" | exit)
        end
      );

      def source(level; mode): (
        .source |
          if (has("string")) then (
            ("source /proc/self/fd/0 <<< " + (.string | map(sanitize) | join(" "))) | indent(level)
          ) elif (has("from")) then (
            (if (mode != $MODE.internal) then $MODE.quiet else mode end) as $mode |
              ("source <(\n" | indent(level)) +
              (.from | map(sourceable($mode) | indent(level + 1)) | join("\n")) + "\n" +
              (")" | indent(level))
            ) else (
            "Authorized fields into source JSON object are \"string\" and \"from\"" | exit
          ) end
      );

      def register(level; mode): (
        .register as $input | .register |
        (if (mode == $MODE.internal) then 0 else 1 end) as $offset |
          if (has("into") | not) then (
            ".register used without .register.into" | exit
          ) else . end |
          if (among(["group", "arithmetic"]) == 2) then (
            "You can only use one of \"group\" or \"arithmetic\" fields into register" | exit
          ) else . end |
          if (has("group")) then (
            group(level + $offset; mode) |
            {
              assign: {
                name: $input.into,
                value: [
                  [
                    {
                      unsanitized: (
                        "\"$(" + . + "; " + (
                          if (mode != $MODE.internal) then (
                            "declare -f " + $PREFIX.function.internal + "autoincr >&3"
                          ) else "" end
                        ) + ")\""
                      )
                    }
                  ]
                ]
              }
            } | assign(level + $offset; false) |
            if (mode != $MODE.internal) then (
              # TODO
              ("coproc CAT { cat; }\n" | indent(level)) +
              ("{\n" | indent(level)) + . + "\n" +
              ("} 3>&${CAT[1]}\n" | indent(level)) +
              ("exec {CAT[1]}>&-\n" | indent(level)) +
              # TODO
              ("mapfile source_me <&${CAT[0]}\n" | indent(level)) +
              ("source /proc/self/fd/0 <<< \"${source_me[@]}\"\n" | indent(level)) +
              ("unset source_me\n" | indent(level))
            ) else . end
          ) elif (has("arithmetic")) then (
            arithmetic(-1) |
            {
              assign: {
                name: $input.into,
                value: [
                  [
                    {
                      unsanitized: ("\"$" + . + "\"")
                    }
                  ]
                ]
              }
            } | assign(level + $offset; false)
          ) else (
            "Authorized fields into register are: arithmetic and group" | exit
          ) end
      );

      is_unique_key_object |

      if (has("harden")) then (
        harden(level; mode)
      ) elif (has("assign")) then (
        assign(level; true)
      ) elif (has("define")) then (
        define(level; mode)
      ) elif (has("readonly")) then (
        readonly(level)
      ) elif (has("if")) then (
        conditional(level; mode)
      ) elif (has("switch")) then (
        switch(level; mode)
      ) elif (has("defer")) then (
        defer(level; mode)
      ) elif (has("register")) then (
        register(level; mode)
      ) elif (has("parameters")) then (
        parameters(level)
      ) elif (has("capture") or has("restore")) then (
        capture_restore(level)
      ) elif (has("on") or has("off")) then (
        on_off(level)
      ) elif (has("source")) then (
        source(level; mode)
      ) elif (has("arithmetic")) then (
        arithmetic(level)
      ) elif (has("print")) then (
        print(level)
      ) elif (has("return")) then (
        return(level)
      ) elif (has("skip")) then (
        skip(level)
      ) elif (has("raw")) then (
        raw(level; mode)
      ) elif (has("initialized")) then (
        $MODE.user
      ) else (
        traceable(level; mode) | join("\n")
      ) end
    );

    (
      "{\n"
    ) + (
      reduce .group[] as $item (
        {
          mode: mode,
          output: []
        };
        . as $reduce_input |
        ($item | command(level + 1; $reduce_input.mode)) as $output |
        if ($output | type == "string") then (
          {
            mode: $reduce_input.mode,
            output: ($reduce_input.output + (if ($output | length == 0) then [] else [$output] end))
          }
        ) elif ($output | type == "number") then (
          {
            mode: $output,
            output: $reduce_input.output
          }
        ) end
      ) | .output | join("\n")
    ) + "\n" + (
      "}" | indent(level)
    )
  );

  .define |
    (group(level; mode)) as $group |
    if (.name | is_legit | not) then (
      bad_varname
    ) else . end | (
      (
        if (mode == $MODE.internal) then (
          $PREFIX.function.internal
        ) else (
          $PREFIX.function.user
        ) end + .name + " ()\n"
      ) | indent(level)
    ) + $group + "\n"
);

def main: (
  # TODO: 1 level is enough
  -1 as $level |
    . as $input |
    {
      define: {
        name: "main",
        group: (
          [
            {raw: {command: ($PREFIX.function.internal + "init"), args: []}},
            {harden: {command: [{literal: "id"}]}},
            {register: {group: [{raw: {command: "id", args: [[{literal: "--user"}], [{literal: "--name"}]]}}], into: [{literal: "user"}]}},
            {assign: {name: [{literal: "user"}], value: [[{var: "USER", default: [{var: "user"}]}]]}},
            {register: {group: [{raw: {command: "id", args: [[{literal: "--user"}]]}}], into: [{literal: "uid"}]}},
            {assign: {name: [{literal: "uid"}], value: [[{var: "UID", default: [{var: "uid"}]}]]}},
            {assign: {name: [{literal: "home"}]}},
            {print: {format: "%s", var: "home", args: [[{char: "tilde"}]]}},
            {assign: {name: [{literal: "home"}], value: [[{var: "HOME", default: [{var: "home"}]}]]}},
            {assign: {name: [{literal: "runner_name"}], value: [[{literal: (input_filename | sub(".*/";"") | sub("\\.yml$";""))}]]}},
            {readonly: [[{literal: "user"}], [{literal: "uid"}], [{literal: "home"}], [{literal: "runner_name"}]]},
            {initialized: true}
          ] + $input.group
        )
      }
    } | define($level; $MODE.internal)
);

def internals: (
  # TODO: 1 level is enough
  -1 as $level |
    [
      {
        define: {
          name: "init",
          group: [
            {on: [[{literal: "errexit"}], [{literal: "errtrace"}], [{literal: "noclobber"}], [{literal: "nounset"}], [{literal: "pipefail"}], [{literal: "lastpipe"}], [{literal: "extglob"}]]},
            {raw: {command: "bash_setup", args: []}},
            {raw: {command: "load_resources", args: []}},
            {raw: {command: "init", args: []}}
          ]
        }
      },
      {
        define: {
          name: "call",
          group: [
            {
              register: {
                into: [{literal: "authorized"}],
                group: [{raw: {command: "compgen", args: [[{literal: "-A"}], [{literal: "function"}], [{literal: "-X"}], [{literal: ("!" + $PREFIX.function.user + "*")}]]}}]
              }
            },
            {parameters: [[{var: "authorized"}], [{literal: "|"}], [{parameter: 1}]]},
            {
              switch: {
                evaluate: [{parameter: 2}, {parameter: 1, replace: {all: [{char: "newline"}], with: [{parameter: 2}]}}, {parameter: 2}],
                branches: [
                  {pattern: [{char: "asterisk"}, {parameter: 2}, {parameter: 3, replace: {end: [{literal: " "}, {char: "asterisk"}], match: "longest"}}, {parameter: 2}, {char: "asterisk"}], group: [{source: {from: [{print: {format: "%s", args: [[{parameter: 3}]]}}]}}]},
                  {pattern: [{char: "asterisk"}], group: [{print: {format: "Unknown \"%s\". You probably forgot to harden a command, to define a function or to enable a disabled builtin\\n", args: [[{parameter: 3}]], to: "stderr"}}, {return: 1}]}
                ]
              }
            }
          ]
        }
      },
      {
        define: {
          name: "autoincr",
          group: [
            {assign: {name: [{literal: "REPLY"}], value: [[{literal: "1"}]], scope: "global"}},
            {register: {into: [{literal: "fn"}], group: [{raw: {command: "declare", args: [[{literal: "-f"}], [{var: "FUNCNAME", index: 0}]], pipe: {raw: {command: "sed", args: [[{var: "sed", key: [{literal: "autoincr"}]}]]}}}}]}},
            {source: {string: [[{var: "fn"}]]}}
          ]
        }
      },
      {
        define: {
          name: "color",
          group: [
            {register: {into: [{literal: "i"}], arithmetic: {left: {arithmetic: {left: {parameter: 1}, op: "modulo", right: {number: ($ARGS.positional | length)}}}, op: "add", right: {number: 1}}}},
            {assign: {name: [{literal: "colors"}], type: "indexed", value: ($ARGS.positional | map([{literal: .}]))}},
            {assign: {name: [{literal: "REPLY"}], value: [[{var: "colors", key: [{var: "i"}]}]], scope: "global"}}
          ]
        }
      }
    ] | map(define($level; $MODE.internal)) | join("")
);

def yml2bash: (
  0 as $level |
    $ARGS.named.env + "\n" +
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
