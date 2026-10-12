<?php // OK: стрелочная функция, немедленный вызов, передача как аргумент
$square = fn($x) => $x * $x;
$result = (function() { return 42; })();
$mapped = array_map(fn($v) => $v + 1, [1, 2, 3]);
