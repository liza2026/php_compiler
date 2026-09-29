<?php

// enum
enum Suit {
    case Hearts;
    case Spades;
}

enum Status: int {
    case Active = 1;
    case Inactive = 0;
}

enum Suit: string implements HasColor {
    case Hearts = 'H';
    public function color(): string { return 'red'; }
}

// readonly-свойства
class Point {
    public function __construct(
        public readonly int $x,
        public readonly int $y,
    ) {}
}
readonly class B {}

// генераторы: yield, yield from
function numbers() {
    yield 1;
    yield 2 => 'two';
    yield from [3, 4, 5];
}

yield;
yield $x;
yield $k => $v;
yield from $gen;

// list() - деструктуризация (наравне с [$a, $b] = ...)
list($a, $b) = [1, 2];
[$c, $d] = [3, 4];

// isset / unset / empty - языковые конструкции, не функции
if (isset($a) && !empty($b)) {
    unset($c);
}

// exit / die
exit;
exit(1);
die;
die('error message');
exit;
exit();
die;
die();

// clone
$copy = clone $point;

// goto
goto end;
end:

// declare / enddeclare (альтернативный синтаксис)
declare(strict_types=1);
declare(ticks=1):
    echo 'tick';
enddeclare;
declare(ticks=1) {
    // блок
}
declare(encoding='UTF-8');

// abstract / final
abstract class Shape {
    abstract public function area(): float;
}
final class Circle extends Shape {
    public function area(): float { return 3.14; }
}

// var - старый стиль объявления свойства
class Legacy {
    var $oldStyleProperty;
}

// include / require и их once-варианты
include 'header.php';
include_once 'header.php';
require 'config.php';
require_once 'config.php';
include $file;
include_once $path;
require __DIR__ . '/x.php';

// insteadof - разрешение конфликтов имён трейтов
trait A { public function hello() {} }
trait B { public function hello() {} }
class C {
    use A, B {
        A::hello insteadof B;
    }
}

// магические константы
function magic() {
    echo __LINE__;
    echo __FILE__;
    echo __DIR__;
    echo __FUNCTION__;
    echo __CLASS__;
    echo __METHOD__;
    echo __NAMESPACE__;
    echo __TRAIT__;
}

function f(): never { throw new Exception(); }
function g(): mixed { return 1; }
function h(): void {}

match($x) {
    1, 2 => 'a',
    default => 'b',
};
