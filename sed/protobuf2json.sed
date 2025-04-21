# !/usr/bin/env --split-string sed --file

# Add `]` before each `}`
s/^\(\s*\)}$/\1]}/g

# Add `"` around PROTOBUF message fields and braces around key-value pair => JSON object
s/^\(\s*\)\([^:]*\): \(.*\)/\1{"\2": \3}/

# Add `"` around PROTOBUF message types, `{` before and replace trailing `{` with `[`
s/^\(\s*\)\(\S\+\) {/\1{"\2": [/

# Add `\` before `\[0-9]` to avoid jq parse error
s/\\\([0-9]\)/\\\\\1/g

# Append every input line to the SED hold space
H

# The first line overwrites the SED hold space
1h

# Delete every line not the last from output
$!d

# Switch the contents of the SED hold space and the SED pattern space
x

# Remove `\n` when just after `[`
s/\[\n\s*/[/g

# Remove `\n` between `}` and `]`
s/}\n\s*]/}]/g

# Replace `\n` between `}` and `{` with `,`
s/}\n\s*{/}, {/g

# Add `{` and `}` as first and last characters into the final output => JSON array
s/^/[/
s/$/]/
