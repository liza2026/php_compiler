<?php

// Spread / variadic (...)
function sum(...$nums) { return array_sum($nums); }
$values = [1, 2, 3];
$total = sum(...$values);
$merged = [...$values, 4, 5, ...[6, 7]];
$namedSpread = [...$values, 'x' => 1];

// First-class callable syntax - тоже использует "..."
$fn = strlen(...);

// Null-safe оператор доступа к свойству/методу
$city = $user?->address?->city;
$name = $user?->getName();
$user?->address?->city;
$user?->getAddress()?->city;
$user?->address['city'];
$user?->method()?->prop;
$arr[0]?->foo;
$a ? $b->c : $d;    // тернарник + обычный ->
$a ?-> b;           // null-safe
$a ?->b;            // без пробелов

// Оператор объединения с null и его составная форма
$value = $input ?? 'default';
$config['key'] ??= 'default';

// Тернарный оператор и его короткая форма
$result = $a ? $b : $c;
$result2 = $a ?: $b;
$a ? $b : $c ? $d : $e;   // вложенный

// Оператор сравнения (spaceship)
$cmp = $a <=> $b;

// Строгое и нестрогое сравнение
$eq = $a == $b;
$strictEq = $a === $b;
$neq = $a != $b;
$oldNeq = $a <> $b;
$strictNeq = $a !== $b;
$a <=> $b;
$a << $b;
$a < $b;
$a <= $b;
$a??$b;
$a??=$b;
$a&&$b;
$a||$b;
$a+++$b;
$a---$b;

// Битовые операции и сдвиги
$and = $a & $b;
$or = $a | $b;
$xorOp = $a ^ $b;
$not = ~$a;
$shl = $a << 2;
$shr = $a >> 2;

// Все составные операторы присваивания
$a += 1; $a -= 1; $a *= 2; $a /= 2; $a %= 2; $a **= 2;
$a .= 'x'; $a &= 1; $a |= 1; $a ^= 1; $a <<= 1; $a >>= 1; $a ??= 1;

// Инкремент/декремент, пре- и постфиксный
$a++; ++$a; $a--; --$a;
$arr[0]++;
$obj->prop++;
$arr[$i]--;
++$arr[0];

// Возведение в степень
$pow = 2 ** 10;

// Подавление ошибок
$safe = @file_get_contents('missing.txt');
@$a;
@foo();
@$arr['key'];
@($a + $b);
@include 'file.php';
@require 'file.php';

// Логические операторы
$logic1 = $a && $b || $c;
$logic2 = $a and $b or $c xor $d;

$a ?? $b;      // coalesce
$a ? ? $b;     // синтаксическая ошибка
$a ??? $b;     // ошибка

// вместе
$user?->name ?? 'default';
$user?->getAddress()?->city ?? 'unknown';

// операторы в скобках интерполяции
echo "{$a + $b}";
echo "{$a ?? 'x'}";
echo "{$a ?: 'y'}";
