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
  def expansion: (
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
        ) + ($input | expansion) + "}\""
      ) else (
        $input.var | bad_varname
      ) end
    ) elif (has("parameter")) then (
      if (.parameter | tostring | test("^[0-9]+$")) then (
        "\"${" + (.parameter | tostring) + ($input | expansion) + "}\""
      ) else (
        "Positional parameter only contains numeric characters" | exit
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

def call(mode): (
  . as $input |
    if (mode == $MODE.internal) then (
      (.call + " " + (.args | map(sanitize) | join(" "))) | remove_useless_quotes
    ) else (
      $PREFIX.function.internal + "call \"" + (($PREFIX.function.user + .call + " " + (.args | map(sanitize) | join(" "))) | remove_useless_quotes) + "\""
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
        xtrace: ($input.call + " " + ($input.args | map(sanitize) | join(" ")))
      }
    ) else (
      "Unknown traceable type: \"" + ($input | tostring) + "\"" | exit
    ) end | xtrace(mode) | map(indent(level))
  ) end
);

def deferrable(level; mode): (
  traceable(level; mode)
);

def conditionnable(level; mode): (
  traceable(level; mode)
);

def harden(level; mode): (
  (
    "harden " + (.harden | sanitize)+ (
      if (has("as")) then (
        .as |
          if (is_reserved) then (
            "You can not use a reserved BASH word to harden a command:" + ($ARGS.named.reserved | gsub("\n"; " ")) | exit
          ) elif (is_legit) then (
            " " + (
              if (mode != $MODE.internal) then (
                $PREFIX.function.user
              ) else "" end
            ) + .
          ) else (
            bad_varname
          ) end
      ) elif (mode != $MODE.internal) then (
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

def print(level): (
  ("printf '" + .print + "' " + (.args | map(sanitize) | join(" "))) | indent(level)
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
        ("source < <(\n" | indent(level)) +
        (.from | map(sourceable($mode) | indent(level + 1)) | join("\n")) + "\n" +
        (")" | indent(level))
      ) else (
      "Authorized fields into source JSON object are \"string\" and \"from\"" | exit
    ) end
);

def define(level; mode): (
  def block(level; mode): (
    def conditional(level; mode): (
      def conditional_inner(level; mode): (
        # check "run" field is an array
        if ((.run | type) != "array") then (
          "Conditional \"run\" field must be an array type but it is \"" + (.run | type) + "\"" | exit
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
              run: ($input | .run[] | block(level + 1; mode))
            }
          ]) |
            {
              cond: ($op.program.before + ($op.yml | conditionnable(-1; mode) | join("; ")) + $op.program.after),
              run: (map(.run) | join("\n")),
            }
      );

      . as $input |
      if (.if | has("run") | not) then (
        ".if used without .if.run" | exit
      ) else . end |
      ($input.if | conditional_inner(level; mode)) as $if |
      {
        if: $if,
        else: []
      } as $output |
        $input |
        if (has("else")) then (
          $output | setpath(["else"]; .else + [
            $input.else[] | conditional_inner(level; mode)
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

    def register(level; mode): (
      . as $input |
      (if (mode == $MODE.internal) then 0 else 1 end) as $offset |
        if (. | has("into") | not) then (
          ".register used without .into" | exit
        ) else . end |
        .register[] | block(level + $offset + 1; mode) |
        {
          assign: $input.into,
          value: [
            [
              {
                unsanitized: ("\"$(\n" + . + "\n" + (
                  if (mode != $MODE.internal) then (
                    "declare -f " + $PREFIX.function.internal + "autoincr >&3\n" | indent(level + $offset + 1)
                  ) else "" end
                ) + (")\"" | indent(level + $offset)))
              }
            ]
          ]
        } | assign(level + $offset; false) |
        if (mode != $MODE.internal) then (
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
      harden(level; mode)
    ) elif (has("assign")) then (
      assign(level; true)
    ) elif (has("define")) then (
      define(level; mode)
    ) elif (has("readonly")) then (
      readonly(level)
    ) elif (has("if")) then (
      conditional(level; mode)
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
    ) elif (has("print")) then (
      print(level)
    ) elif (has("initialized")) then (
      $MODE.user
    ) else (
      traceable(level; mode) | join("\n")
    ) end
  );

  . as $input | .define |
    if (is_reserved) then (
      "You can not define a function with a reserved BASH word:" + ($ARGS.named.reserved | gsub("\n"; " ")) | exit
    ) elif (is_legit | not) then (
      bad_varname
    ) else . end | ((
    if (mode == $MODE.internal) then (
      $PREFIX.function.internal
    ) else (
      $PREFIX.function.user
    ) end + . + " ()\n") | indent(level)) + (
    "{\n" | indent(level)) + (
    [
      foreach $input.run[] as $item (
        {
          mode: mode
        };
        . as $foreach_input |
        ($item | block(level + 1; $foreach_input.mode)) as $output |
        if ($output | type == "string") then (
          {
            mode: $foreach_input.mode,
            extract: $output
          }
        ) elif ($output | type == "number") then (
          {
            mode: $output,
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
      define: "main",
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
    } | define($level; $MODE.internal)
);

def internals: (
  # TODO: 1 level is enough
  -1 as $level |
    [
      {
        define: "init",
        run: [
          {on: [[{literal: "errexit"}], [{literal: "errtrace"}], [{literal: "noclobber"}], [{literal: "nounset"}], [{literal: "pipefail"}], [{literal: "lastpipe"}], [{literal: "extglob"}]]},
          {call: "bash_setup", args: []},
          {call: "load_resources", args: []},
          {call: "init", args: []}
        ]
      },
      {
        define: "call2",
        run: [
          {capture: true},
          {on: [[{literal: "noglob"}]]},
          {
            into: [{literal: "authorized"}],
            register: [{call: "compgen", args: [[{literal: "-A"}], [{literal: "function"}], [{literal: "-A"}], [{literal: "enabled"}]]}]
          },
          {parameters: [[{var: "authorized"}], [{literal: "|"}], [{parameter: 1}]]},
          {restore: true},
          # TODO: case statement
          {source: {from: [{print: "%s", args: [[{parameter: 3}]]}]}}
        ]
      }
    ] | map(define($level; $MODE.internal)) | join("")
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
