# !/usr/bin/env -S jq -f

def esc_seq(code): "\u001B[" + code + "m";
def fg(color): esc_seq("38;5;" + (color | tostring));
def bold: esc_seq("1");
def reset: esc_seq("0");

def colored(text; color):
  fg(color) + bold + text + reset;
