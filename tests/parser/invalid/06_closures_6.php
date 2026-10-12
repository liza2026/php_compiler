<?php // FAIL (line 2, compile): параметр совпадает с переменной из use (ошибка компиляции)
$f = function($x) use ($x) {
    return $x;
};
