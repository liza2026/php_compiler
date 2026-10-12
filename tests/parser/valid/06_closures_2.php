<?php // OK: захват use по значению и по ссылке, несколько переменных
$x = 10;
$y = 1;
$adder = function($z) use ($x, $y) {
    return $x + $y + $z;
};
$adderRef = function($z) use (&$x) {
    $x += $z;
};
