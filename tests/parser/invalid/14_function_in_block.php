<?php // FAIL (line 3, parse): объявление функции внутри блока не поддерживается
while ($x) {
    function f() {}
}
