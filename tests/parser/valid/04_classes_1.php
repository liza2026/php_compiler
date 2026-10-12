<?php // OK: класс со свойством и методом, создание объекта, вызов метода
class Animal {
    public $name;
    function speak() {
        echo "...";
    }
}
$a = new Animal();
$a->speak();
echo $a->name;
