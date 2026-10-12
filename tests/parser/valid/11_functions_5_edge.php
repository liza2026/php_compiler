<?php // OK: пустое тело, висячая запятая в параметрах и аргументах, рекурсия
function noop() {}
function trailing($a, $b,) {}
trailing(1, 2,);
function fact($n) { return $n <= 1 ? 1 : $n * fact($n - 1); }
