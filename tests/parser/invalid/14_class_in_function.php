<?php // FAIL (line 3, parse): объявление класса внутри функции не поддерживается
function g() {
    class A {}
}
