<?php // OK: типы параметров и возврата, ?nullable, union, возврат по ссылке
function typed(int $a, ?string $b = null, int|float $c = 0): string {
    return "ok";
}
function &getRef(array &$arr) {
    return $arr;
}
function nothing(): void {}
