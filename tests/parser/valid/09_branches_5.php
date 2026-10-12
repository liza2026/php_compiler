<?php // OK: match: несколько условий, default, висячая запятая
$status = match(true) {
    $x > 0 => "positive",
    $x < 0 => "negative",
    default => "zero",
};
$name = match($code) {
    1, 2, 3 => "low",
    4 => "mid",
};
