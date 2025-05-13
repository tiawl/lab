# !/usr/bin/env --split-string gojq --from-file

# TODO:
# - more checks
# - op:
#   - and
#   - or
#   - [[ ]]
# - loop:
#   - in:     for <name> [ [ in [ <word> ... ] ] ; ] do <list>; done
#   - while:  while list-1; do list-2; done
#             while [[ expression ]]; do list-2; done
#   - for:    for (( <expr1> ; <expr2> ; <expr3> )) ; do <list> ; done
# - async/wait

{
  user: "__",
  internal: "_"
} as $NAMESPACE |
{
  internal: -1,
  quiet: 0,
  user: 1
} as $MODE |
-2 as $NOINDENT |

def incr_indent_level(i): (
  if (. == $NOINDENT) then $NOINDENT else (. + i) end
);

def indent(level): (
  ((" " * ((level | incr_indent_level(1)) * 4)) // "") + .
);

def is_legit_varname: (
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

def sanitize(mode): (
  def expansion(mode): (
    if (among(["default", "alternate", "replace", "prompt"]) == 2) then (
      "You can only use one of \"default\", \"alternate\", \"replace\" or \"prompt\" fields for a same variable" | exit
    ) else . end |
    if (has("default")) then (
      ":-" + (.default | sanitize(mode))
    ) elif (has("alternate")) then (
      ":+" + (.alternate | sanitize(mode))
    ) elif (has("prompt") and .prompt) then (
      "@P"
    ) elif (has("replace")) then (
      .replace |
        if (has("all")) then (
          "//" + (.all | sanitize(mode)) + (if (has("with")) then ("/" + (.with | sanitize(mode))) else "" end)
        ) elif (has("first")) then (
          "/" + (.first | sanitize(mode)) + (if (has("with")) then ("/" + (.with | sanitize(mode))) else "" end)
        ) elif (has("start") and (.match == "shortest")) then (
          "#" + (.start | sanitize(mode))
        ) elif (has("start") and (.match == "longest")) then (
          "##" + (.start | sanitize(mode))
        ) elif (has("end") and (.match == "shortest")) then (
          "%" + (.end | sanitize(mode))
        ) elif (has("end") and (.match == "longest")) then (
          "%%" + (.end | sanitize(mode))
        ) else (
          "Unknown field into \"replace\": " + (. | tostring) | exit
        ) end
    ) else "" end
  );

  def variable(name; mode): (
    "\"${" + name + (
      if (has("key")) then (
        "[" + (.key | sanitize(mode)) + "]"
      ) elif (has("index")) then (
        if (.index | type == "number") then (
          "[" + (.index | tostring) + "]"
        ) else (
          "The .var.index must be number typed" | exit
        ) end
      ) else "" end
    ) + expansion(mode) + "}\""
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
      ) elif (.char == "atsign") then (
        "@"
      ) elif (.char == "newline") then (
        "$'\\n'"
      ) else (
        "Unknown char: \"" + .char + "\"" | exit
      ) end
    ) elif (has("var")) then (
      if (.var | is_legit_varname) then (
        variable(if (mode != $MODE.internal) then $NAMESPACE.user else "" end + .var; mode)
      ) else (
        $input.var | bad_varname
      ) end
    ) elif (has("parameter")) then (
      if (.parameter | type == "number") then (
        variable(.parameter | tostring; mode)
      ) else (
        "Positional parameter must be number typed" | exit
      ) end
    ) elif (has("special")) then (
      variable(
        if (.special == "last") then "_"
        elif ((.special == "FUNCNAME") or (.special == "USER") or (.special == "UID") or (.special == "HOME") or (.special == "RUNNER") or (.special == "sep")) then .special
        else (
          "Unknown special variable: \"" + .special + "\"" | exit
        ) end
      ; mode)
    ) elif (has("file")) then (
      "\"$(< " + (.file | sanitize(mode)) + ")\""
    ) else (
      "Unknown field object passing through sanitize(): \"" + keys[0] + "\"" | exit
    ) end
  ) | join("")
);

def xtrace(mode): (
  if (mode == $MODE.user) then (
    [
      $NAMESPACE.internal + "xtrace \"" + (.xtrace | remove_useless_quotes) + "\"",
      .program
    ]
  ) else (
    [
      .program
    ]
  ) end
);

def orchestrator(mode): {
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
              ($defined.image | sanitize(mode)) + " " +
              ($defined.tag | sanitize(mode))
          ) else null end
      ) catch null),
      create: (try (
        .image.tag.create as $create |
          if $create then (
            "image tag create " +
              ($create.from.image | sanitize(mode)) + " " +
              ($create.from.tag | sanitize(mode)) + " " +
              ($create.to.image | sanitize(mode)) + " " +
              ($create.to.tag | sanitize(mode))
          ) else null end
      ) catch null)
    },
    pull: (try (
      .image.pull as $pull |
        if $pull then (
          "image pull " +
            ($pull.registry | sanitize(mode)) + " " +
            ($pull.library | sanitize(mode)) + " " +
            ($pull.image | sanitize(mode)) + " " +
            ($pull.tag | sanitize(mode))
        ) else null end
    ) catch null),
    remove: (try (
      .image.remove as $remove |
        if $remove then (
          "image remove " +
            ($remove.image | sanitize(mode)) + " " +
            ($remove.tag | sanitize(mode))
        ) else null end
    ) catch null),
    prune: (try (
      .image.prune as $prune |
        if $prune then (
          "image prune " +
            ($prune.matching | sanitize(mode))
        ) else null end
    ) catch null),
    build: (try (
      .image.build as $build |
        if $build then (
          "image build " +
            ($build.image | sanitize(mode)) + " " +
            ($build.context | sanitize(mode)) + " " +
            ([$build.args[][] | sanitize(mode)] | join(" "))
        ) else null end
    ) catch null)
  },
  container: {
    resource: {
      copy: (try (
        .container.resource.copy as $copy |
          if $copy then (
            "container resource copy " +
              ($copy.name | sanitize(mode)) + " " +
              ($copy.src | sanitize(mode)) + " " +
              ($copy.dest | sanitize(mode))
          ) else null end
      ) catch null)
    },
    create: (try (
      .container.create as $create |
        if $create then (
          "container create " +
            ($create.name | sanitize(mode)) + " " +
            ($create.image | sanitize(mode)) + " " +
            ($create.hostname | sanitize(mode))
        ) else null end
    ) catch null),
    start: (try (
      .container.start as $start |
        if $start then (
          "container start " +
            ($start.name | sanitize(mode))
        ) else null end
    ) catch null),
    stop: (try (
      .container.stop as $stop |
        if $stop then (
          "container stop " +
            ($stop.name | sanitize(mode))
        ) else null end
    ) catch null)
  },
  network: {
    ip: {
      get: (try (
        .network.ip.get as $get |
          if $get then (
            "network ip get " +
              ($get.container | sanitize(mode))
          ) else null end
      ) catch null)
    }
  }
};

def harden(level; mode): (
  (
    .harden |
    "harden " + (.command | sanitize(mode)) + (
      if (has("as") and (.as | length > 0)) then (
        " " + (
          if (mode != $MODE.internal) then (
            $NAMESPACE.user
          ) else "" end
        ) + (.as | sanitize(mode))
      ) elif (mode != $MODE.internal) then (
        " '" + $NAMESPACE.user + "'" + (.command | sanitize(mode)) | gsub("''"; "")
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

def assign(level; mode; sanitized_value): (
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
  if ((.name | length == 1) and (.name[0] | has("special")) and (.name[0].special == "last")) then (
    ": "
  ) else (
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
    ) + (
      if (mode != $MODE.internal) then $NAMESPACE.user else "" end + (.name | sanitize(mode))
    ) + (
      if (has("key")) then (
        "[" + (.key | sanitize(mode)) + "]"
      ) else "" end
    ) + if (has("value")) then "=" else "" end
  ) end + (
    if (has("value")) then (
      if (sanitized_value) then (
        if (($input.type == "indexed") or ($input.type == "associative")) then (
          ("'('" + (.value | map(sanitize(mode)) | join("' '")) + "')'") | gsub("''"; "")
        ) else (
          .value[0] | sanitize(mode)
        ) end
      ) else (
        .value[][0].unsanitized
      ) end
    ) else "" end
  ) | indent(level)
);

def readonly(level; mode): (
  ("readonly -- " + (.readonly | map(if (mode != $MODE.internal) then $NAMESPACE.user else "" end + (. | sanitize(mode))) | join(" "))) | indent(level)
);

def print(level; mode): (
  (
    .print |
    "printf " + (
      if (has("var")) then (
        if (.var | is_legit_varname) then (
          "-v " + (if (mode != $MODE.internal) then $NAMESPACE.user else "" end) + .var + " "
        ) else (
          .var | bad_varname
        ) end
      ) else "" end
    ) + "-- '" + .format + "' " + (.args | map(sanitize(mode)) | join(" "))
  ) | indent(level)
);

def return(level): (
  ("return " + (.return | tostring)) | indent(level)
);

def skip(level; mode): (
  (": " + (.skip | map(sanitize(mode)) | join(" "))) | indent(level)
);

def on_off(level; mode): (
  ((keys[0]) + " " + (values[] | map(sanitize(mode)) | join(" "))) | indent(level)
);

def capture_restore(level): (
  if (.capture or .restore) then (keys[0] | indent(level)) else "" end
);

def parameters(level; mode): (
  ("set -- " + (.parameters | map(sanitize(mode)) | join(" "))) | indent(level)
);

def arithmetic(level; mode): (
  def arithmetic_inner(mode): (
    def arithmetic_op: (
      if (.op == "add") then (
        "+"
      ) elif (.op == "modulo") then (
        "%"
      ) else (
        "Unknown arithmetic operand: " + . | exit
      ) end
    );

    def arithmetic_side(mode): (
      is_unique_key_object |

      if ((has("parameter")) or (has("var"))) then (
        [.] | sanitize(mode)
      ) elif (has("number")) then (
        if (.number | type == "number") then (
          .number | tostring
        ) else (
          ".number arithmetic side must be number typed" | exit
        ) end
      ) elif (has("arithmetic")) then (
        .arithmetic | arithmetic_inner(mode)
      ) else (
        "Unknown arithmetic side: " + (. | tostring) | exit
      ) end
    );

    "( " + (.left | arithmetic_side(mode)) + " " + (arithmetic_op) + " " + (.right | arithmetic_side(mode)) + " )"
  );

  ("(" + (.arithmetic | arithmetic_inner(mode)) + ")") | indent(level)
);

def define(level; mode): (
  def group(level; mode; multilined; indent_first): (
    def command(level; mode; multilined): (
      def switch(level; mode): (
        .switch as $input | .switch |
          ("case " + (.evaluate | sanitize(mode)) + " in\n") | indent(level) + (
            $input.branches | map(
              . as $branch |
              ("( " + ($branch.pattern | sanitize(mode)) + " ) ") | indent(level) +
              ($branch | group(level; mode; true; false)) + " ;;\n"
            ) | join("")
          ) + ("esac" | indent(level))
      );

      def raw(level; mode): (
        .raw |
          if (mode == $MODE.internal) then (
            (.command + " " + (.args | map(sanitize(mode)) | join(" ")) + (
              if (has("pipe")) then (
                " | " + (.pipe | group($NOINDENT; mode; false; false))
              ) else "" end
            )) | indent(level)
          ) else (
            "\"raw\" can only be used as internal user" | exit
          ) end
      );

      def call(mode): (
        .call |
          $NAMESPACE.internal + "call \"" + (($NAMESPACE.user + .command + " " + (.args | map(sanitize(mode)) | join(" "))) | remove_useless_quotes) + (
            if (has("pipe")) then (
              " | " + (.pipe | group($NOINDENT; mode; false; false))
            ) else "" end
          ) + "\""
      );

      def traceable(level; mode): (
        if (isempty(.[])) then (
          []
        ) else (
          . as $input | (
            (
              orchestrator(mode) |
                walk(
                  if (type == "object") then (
                    with_entries(select((.value != null) and (.value | (type == "object" and length == 0) | not)))
                  ) else . end
                ) | .. | select(type == "string")
            ) // null
          ) as $program |
          if ($program | type == "string") then (
            {
              program: $program,
              xtrace: $program
            }
          ) elif ($input | has("call")) then (
            {
              program: ($input | call(mode)),
              xtrace: ($input.call.command + " " + ($input.call.args | map(sanitize(mode)) | join(" ")))
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
            if (startswith($NAMESPACE.internal + "xtrace")) then (
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
          def conditional_op(mode): (
            if (has("not")) then (
              "{ ! " + (.not | conditional_op(mode)) + "; }"
            ) else (
              group($NOINDENT; mode; false; false)
            ) end
          );

          {
            cond: (
              # "else" case
              if ((type == "object") and (keys | length == 1) and (keys[0] == "group")) then (
                ""
              # "if" and "elif" cases
              ) else (
                conditional_op(mode)
              ) end
            ),
            group: group(level; mode; true; false),
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
        elif (has("print")) then print(-1; mode)
        else ("Authorized tasks into source.from JSON array are \"call\" and \"print\"" | exit)
        end
      );

      def source(level; mode): (
        .source |
          if (has("string")) then (
            ("source /proc/self/fd/0 <<< " + (.string | map(sanitize(mode)) | join(" "))) | indent(level)
          ) elif (has("from")) then (
            (if (mode != $MODE.internal) then $MODE.quiet else mode end) as $mode |
              ("source <(\n" | indent(level)) +
              (.from | map(sourceable($mode) | indent(level | incr_indent_level(1))) | join("\n")) + "\n" +
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
          if (among(["group", "arithmetic", "split"]) == 2) then (
            "You can only use one of \"group\", \"arithmetic\" or \"split\" fields into register" | exit
          ) else . end |
          if (has("group")) then (
            group(level | incr_indent_level($offset); mode; true; false) |
            {
              assign: {
                name: $input.into,
                scope: (if ($input | has("scope")) then $input.scope else "local" end),
                value: [
                  [
                    {
                      unsanitized: (
                        "\"$(" + . + "; " + (
                          if (mode != $MODE.internal) then (
                            "declare -f " + $NAMESPACE.internal + "autoincr >&3"
                          ) else "" end
                        ) + ")\""
                      )
                    }
                  ]
                ]
              }
            } | assign(level | incr_indent_level($offset); mode; false) |
            if (mode != $MODE.internal) then (
              # TODO
              ("coproc CAT { cat; }\n" | indent(level)) +
              ("{\n" | indent(level)) + . + "\n" +
              ("} 3>&${CAT[1]}\n" | indent(level)) +
              ("exec {CAT[1]}>&-\n" | indent(level)) +
              ("mapfile source_me <&${CAT[0]}\n" | indent(level)) +
              ("source /proc/self/fd/0 <<< \"${source_me[@]}\"\n" | indent(level)) +
              ("unset source_me\n" | indent(level))
            ) else . end
          ) elif (has("arithmetic")) then (
            arithmetic(-1; mode) |
            {
              assign: {
                name: $input.into,
                scope: (if ($input | has("scope")) then $input.scope else "local" end),
                value: [
                  [
                    {
                      unsanitized: ("\"$" + . + "\"")
                    }
                  ]
                ]
              }
            } | assign(level | incr_indent_level($offset); mode; false)
          ) elif (has("split")) then (
            ("mapfile -t -d " + ($input.split.delimiter | sanitize(mode)) + " " + ($input.into | sanitize(mode)) + " <<< " + ($input.split.string | sanitize(mode))) | indent(level | incr_indent_level($offset))
          ) else (
            "Authorized fields into register are: arithmetic and group" | exit
          ) end
      );

      is_unique_key_object |

      if (has("harden")) then (
        harden(level; mode)
      ) elif (has("assign")) then (
        assign(level; mode; true)
      ) elif (has("define")) then (
        define(level; mode)
      ) elif (has("readonly")) then (
        readonly(level; mode)
      ) elif (has("if")) then (
        conditional(level; mode)
      ) elif (has("switch")) then (
        switch(level; mode)
      ) elif (has("defer")) then (
        defer(level; mode)
      ) elif (has("register")) then (
        register(level; mode)
      ) elif (has("parameters")) then (
        parameters(level; mode)
      ) elif (has("capture") or has("restore")) then (
        capture_restore(level)
      ) elif (has("on") or has("off")) then (
        on_off(level; mode)
      ) elif (has("source")) then (
        source(level; mode)
      ) elif (has("arithmetic")) then (
        arithmetic(level; mode)
      ) elif (has("print")) then (
        print(level; mode)
      ) elif (has("return")) then (
        return(level)
      ) elif (has("skip")) then (
        skip(level; mode)
      ) elif (has("split")) then (
        split(level)
      ) elif (has("group")) then (
        group(level; mode; multilined; true)
      ) elif (has("raw")) then (
        raw(level; mode)
      ) elif (has("initialized")) then (
        $MODE.user
      ) else (
        traceable(level; mode) | join(if (multilined) then "\n" else "; " end)
      ) end
    );

    def redirections: (
      .redirections | map(
        is_unique_key_object |
        if (has("output")) then (
          .output |
            (.left.fd | tostring) + (if (.appending) then ">>" else ">" end) + (.right | if (has("fd")) then ("&" + (.fd | tostring)) else (" " + .file) end)
        ) else (
          "Unknown redirection type: \"" + keys[0] + "\"" | exit
        ) end
      ) | join(" ")
    );

    (
      if (multilined) then (
        {
          first: "\n",
          between: "\n",
          last: "\n"
        }
      ) else (
        {
          first: " ",
          between: "; ",
          last: "; "
        }
      ) end
    ) as $sep |

    .group as $input |
    (
      ("{" + $sep.first) | if (indent_first) then (indent(level)) else . end
    ) + (
      reduce .group.commands[] as $item (
        {
          mode: mode,
          output: []
        };
        . as $reduce_input |
        ($item | command(level | incr_indent_level(1); $reduce_input.mode; multilined)) as $output |
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
      ) | .output | join($sep.between)
    ) + $sep.last + (
      (
        "}" + (
          if (.group | has("redirections")) then (
            " " + (.group | redirections)
          ) else "" end
        )
      ) | indent(level)
    )
  );

  .define |
    (group(level; mode; true; true)) as $group |
    if (.name | is_legit_varname | not) then (
      bad_varname
    ) else . end | (
      (
        if (mode == $MODE.internal) then (
          $NAMESPACE.internal
        ) else (
          $NAMESPACE.user
        ) end + .name + " ()\n"
      ) | indent(level)
    ) + $group + "\n"
);

def internals(level): (
  [
    {
      define: {
        name: "init_runner",
        group: {
          commands: [
            {on: [[{literal: "errexit"}], [{literal: "errtrace"}], [{literal: "noclobber"}], [{literal: "nounset"}], [{literal: "pipefail"}], [{literal: "lastpipe"}], [{literal: "extglob"}]]},
            {raw: {command: "bash_setup", args: []}},
            {raw: {command: "load_resources", args: []}},
            {raw: {command: "init", args: []}},
            {raw: {command: "unset", args: [[{literal: "path"}, {literal: "version"}]]}}
          ]
        }
      }
    },
    {
      define: {
        name: "call",
        group: {
          commands: [
            {
              register: {
                into: [{literal: "authorized"}],
                group: {commands: [{raw: {command: "compgen", args: [[{literal: "-A"}], [{literal: "function"}], [{literal: "-X"}], [{literal: ("!" + $NAMESPACE.user + "*")}]]}}]}
              }
            },
            {parameters: [[{var: "authorized"}], [{literal: "|"}], [{parameter: 1}]]},
            {
              switch: {
                evaluate: [{parameter: 2}, {parameter: 1, replace: {all: [{char: "newline"}], with: [{parameter: 2}]}}, {parameter: 2}],
                branches: [
                  {pattern: [{char: "asterisk"}, {parameter: 2}, {parameter: 3, replace: {end: [{literal: " "}, {char: "asterisk"}], match: "longest"}}, {parameter: 2}, {char: "asterisk"}], group: {commands: [{source: {from: [{print: {format: "%s", args: [[{parameter: 3}]]}}]}}]}},
                  {pattern: [{char: "asterisk"}], group: {commands: [{group: {commands: [{print: {format: "Unknown \"%s\". You probably forgot to harden a command, to define a function or to enable a disabled builtin\\n", args: [[{parameter: 3}]]}}], redirections: [{output: {left: {fd: 1}, right: {fd: 2}}}]}}, {return: 1}]}}
                ]
              }
            }
          ]
        }
      }
    },
    {
      define: {
        name: "autoincr",
        group: {
          commands: [
            {assign: {name: [{literal: "REPLY"}], value: [[{literal: "1"}]], scope: "global"}},
            {register: {into: [{literal: "fn"}], group: {commands: [{raw: {command: "declare", args: [[{literal: "-f"}], [{special: "FUNCNAME", index: 0}]], pipe: {group: {commands: [{raw: {command: "sed", args: [[{var: "sed", key: [{literal: "autoincr"}]}]]}}]}}}}]}}},
            {source: {string: [[{var: "fn"}]]}}
          ]
        }
      }
    },
    {
      define: {
        name: "color",
        group: {
          commands: [
            {register: {into: [{literal: "i"}], arithmetic: {left: {arithmetic: {left: {parameter: 1}, op: "modulo", right: {number: ($ARGS.positional | length)}}}, op: "add", right: {number: 1}}}},
            {assign: {name: [{literal: "colors"}], type: "indexed", value: ($ARGS.positional | map([{literal: .}]))}},
            {assign: {name: [{literal: "REPLY"}], value: [[{var: "colors", key: [{var: "i"}]}]], scope: "global"}}
          ]
        }
      }
    },
    {
      define: {
        name: "xtrace",
        group: {
          commands: [
            {raw: {command: ($NAMESPACE.internal + "autoincr"), args: []}},
            {parameters: [[{parameter: 1}], [{var: "REPLY"}]]},
            {raw: {command: ($NAMESPACE.internal + "color"), args: [[{parameter: 2}]]}},
            {parameters: [[{parameter: 1}], [{parameter: 2}], [{var: "REPLY"}]]},
            {group: {commands: [{print: {format: "%b\\033[1m%s\\033[0m > %s\\n", args: [[{literal: "\\033[38;5;"}, {parameter: 3}, {literal: "m"}], [{parameter: 2}], [{parameter: 1}]]}}], redirections: [{output: {left: {fd: 1}, right: {fd: 2}}}]}}
          ]
        }
      }
    }
  ] | map(define(level; $MODE.internal)) | join("")
);

def main(level): (
  {
    define: {
      name: "main",
      group: {
        commands: (
          [
            {raw: {command: ($NAMESPACE.internal + "init_runner"), args: []}},
            {register: {group: {commands: [{skip: [[{literal: "\\u"}]]}, {print: {format: "%s", args: [[{special: "last", "prompt": true}]]}}]}, into: [{special: "last"}]}},
            {assign: {name: [{literal: "USER"}], value: [[{special: "USER", default: [{special: "last"}]}]], scope: "global"}},
            {print: {format: "%s", var: "HOME", args: [[{char: "tilde"}]]}},
            {assign: {name: [{literal: "RUNNER"}], value: [[{literal: (input_filename | sub(".*/";"") | sub("\\.yml$";""))}]], scope: "global"}},
            {readonly: [[{literal: "USER"}], [{literal: "HOME"}], [{literal: "RUNNER"}]]},
            {initialized: true}
          ] + .group.commands
        )
      }
    }
  } | define(level; $MODE.internal)
);

def write_runner_script: (
  -1 as $level |
  $ARGS.named.env + "\n" +
  internals($level) +
  main($level) +
  $NAMESPACE.internal + "main \"${@}\""
);

write_runner_script
