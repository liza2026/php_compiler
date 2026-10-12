<?php // OK: пустые тела, if с пустым оператором, вложенность, match только с default
if ($x) {} else {}
if ($x);
if ($a) { if ($b) { if ($c) { echo "deep"; } } }
$r = match($x) { default => 0 };
switch ($x) {}
