# !/usr/bin/env --split-string gojq --from-file

def esc_seq(code): "\u001B[" + code + "m";
def fg(color): esc_seq("38;5;" + (color | tostring));
def bold(text): esc_seq("1") + text;
def text(text; color): fg(color) + text + esc_seq("0");
