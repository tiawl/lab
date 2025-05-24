#! /usr/bin/env --split-string sed --file

/^\s*REPLY='[0-9]\+';\?$/ {
  s/';\?$//

  :replace_trailing_nines_with_underscores
  s/9\(_*\)$/_\1/
  t replace_trailing_nines_with_underscores

  s/='\(_*\)$/='1\1/
  t replace_trailing_underscores_with_zeroes
  s/8\(_*\)$/9\1/
  t replace_trailing_underscores_with_zeroes
  s/7\(_*\)$/8\1/
  t replace_trailing_underscores_with_zeroes
  s/6\(_*\)$/7\1/
  t replace_trailing_underscores_with_zeroes
  s/5\(_*\)$/6\1/
  t replace_trailing_underscores_with_zeroes
  s/4\(_*\)$/5\1/
  t replace_trailing_underscores_with_zeroes
  s/3\(_*\)$/4\1/
  t replace_trailing_underscores_with_zeroes
  s/2\(_*\)$/3\1/
  t replace_trailing_underscores_with_zeroes
  s/1\(_*\)$/2\1/
  t replace_trailing_underscores_with_zeroes
  s/0\(_*\)$/1\1/
  t replace_trailing_underscores_with_zeroes

  :replace_trailing_underscores_with_zeroes
  y/_/0/
  s/$/';/
}
