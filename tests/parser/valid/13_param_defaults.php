<?php // OK: значения по умолчанию только у последних параметров
function f($a, int $b, $c = 1, ?string $d = null, ...$rest) {}
function g($a = 1, $b = 2) {}
function h($a, ...$rest) {}
class A { public function __construct(private int $x, public int $y = 0) {} }
