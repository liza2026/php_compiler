<?php // OK: одна ; перед первым case (PHP не допускает больше), пустые операторы внутри case
switch ($x) { ; case 1: ;; echo 1; ;; break; ;; default: ; ; }
switch ($x): ; case 1; echo 1; break; ;; endswitch;
switch ($x) { ; }
