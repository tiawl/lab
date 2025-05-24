#! /usr/bin/env --split-string sed --file

s/^HTTPS\? 2/\o033[38;5;2m\0/
t end
s/^HTTPS\? [13]/\o033[38;5;6m\0/
t end
s/^HTTPS\? [4-9]/\o033[38;5;1m\0/
:end
s/$/\o033[0m/
