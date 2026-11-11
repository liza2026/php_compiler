<?php // FAIL (line 2, parse): объявление функции в теле if не поддерживается
if ($x) function f() {}
