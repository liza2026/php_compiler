<?php // OK: создание нескольких объектов сразу и класс по имени из переменной
$list = [new Foo(), new Bar(1, 2), new $cls(3)];
$one = new $cls;
$two = new (getClassName())(1);
$filled = array_fill(0, 5, new Foo());
$s = new static();
