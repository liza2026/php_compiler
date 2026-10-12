<?php // OK: наследование и переопределение метода, parent::
class Dog extends Animal {
    function speak() {
        parent::speak();
        echo "Woof";
    }
}
