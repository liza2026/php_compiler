<?php // OK: создание нескольких объектов сразу и класс по имени из переменной
$list = [new Foo(), new Bar(1, 2), new $cls(3)];
$one = new $cls;
$two = new (getClassName())(1);
$many = array_map(fn($i) => new Foo($i), range(1, 5));
$filled = array_fill(0, 5, new Foo());
$c = clone $one;
$s = new static();
