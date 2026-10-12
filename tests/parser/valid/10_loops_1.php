<?php // OK: while и while с альтернативным синтаксисом
$i = 0;
while ($i < 10) {
    $i++;
}
while ($i > 0):
    $i--;
endwhile;
