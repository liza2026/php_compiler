<?php // OK: цель foreach: $v, &$v, $k => $v, $k => &$v, [$a, $b], [&$a, $b], [, $b]
foreach ($a as $v) {}
foreach ($a as &$v) {}
foreach ($a as $k => &$v) {}
foreach ($a as [$x, $y]) {}
foreach ($a as [&$x, $y]) {}
foreach ($a as [, $b]) {}
