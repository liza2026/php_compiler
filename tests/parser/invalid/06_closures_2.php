<?php // FAIL (line 2, parse): use без скобок
$f = function($x) use $x {
    return $x;
};
