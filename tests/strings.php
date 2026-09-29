<?php

'simple single-quoted string'
'string with \'escaped quote\''
'string with \\backslash'
'unrecognized \t escape stays literal'
''

"simple double-quoted string"
"string with \"escaped quote\""
"line1\nline2\ttabbed"
"code by hex \x41\x42\x43"
"code by octal \101\102\103"
""

"multi
line
string"

$name = 'Julia';
"interpolated $name inside"
"escaped dollar: \$100"
"lone dollar sign: $ not a variable"

"concatenated" . "strings" . 'mixed quotes'

// Строки, чтобы проверить разэкранирование:
$a = 'single \n no escape';    // должно быть 2 символа: \ и n
$b = "double \n escape";       // должен быть перевод строки
$c = 'single \' \" quote';     // escape работает только для '
$d = "double \' \" quote";     // escape работает только для "
$e = "tab\there";              // \t
$f = "\x41\101\u{1F600}";      // hex / octal / unicode
$g = "\\";                     // один обратный слэш
$h = '\\';                     // один обратный слэш
$i = "\$notVar";               // экранированный $

echo "unterminated interpolation: {$user->name