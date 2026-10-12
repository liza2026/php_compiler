<?php // OK: пустое тело, static-замыкание, вложенные fn
$noop = function() {};
$id = fn($x) => $x;
$s = static fn() => 1;
$curry = fn($a) => fn($b) => $a + $b;
