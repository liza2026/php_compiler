<?php // OK: параметр по умолчанию, variadic, по ссылке, return без значения
function greet($name, $greeting = "Hello") {
    return $greeting . ", " . $name;
}
function sum(...$nums) {
    return array_sum($nums);
}
function modify(&$x) {
    $x++;
    return;
}
