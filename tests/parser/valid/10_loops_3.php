<?php // OK: for, for с несколькими выражениями, альтернативный синтаксис
for ($i = 0; $i < 10; $i++) {
    echo $i;
}
for ($i = 0, $j = 10; $i < $j; $i++, $j--) {
    echo $i, $j;
}
for ($i = 0; $i < 3; $i++):
    echo $i;
endfor;
