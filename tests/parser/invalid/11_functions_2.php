<?php // FAIL (line 3, parse): не закрыта скобка списка параметров
function f($a, $b {
    return $a + $b;
}
