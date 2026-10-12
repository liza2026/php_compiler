<?php // OK: анонимная функция, присвоенная переменной, и её вызов
$greet = function($name) {
    return "Hello, " . $name;
};
echo $greet("Ann");
