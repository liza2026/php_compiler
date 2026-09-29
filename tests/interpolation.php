<?php

$name = 'Julia';
$user = null;
$arr = ['key' => 'value', 0 => 'zero', -1 => 'neg'];
$key = 'key';

// Простая интерполяция переменной
echo "Hello, $name!";

// Простой доступ к элементу массива (bareword-ключ - трактуется как строка)
echo "Value: $arr[key]";

// Простой доступ по числовому индексу (в т.ч. отрицательному)
echo "Zero: $arr[0], negative: $arr[-1]";

// Простой доступ по переменной-ключу
echo "By var key: $arr[$key]";

// Простой доступ к свойству объекта (только один уровень, без цепочек)
echo "Name: $user->name";

// Устаревший (deprecated 8.2+) синтаксис ${var}
echo "Old style: ${name}";

// Сложная интерполяция {$...} - произвольное выражение
echo "Method call: {$user->getName()}";
echo "Chained: {$user->address->city}";
echo "Nested array with expr key: {$arr[$key]}";
echo "Array literal string key inside braces: {$arr['key']}";
echo "Arithmetic inside interpolation: {$arr[0]} and {$arr[-1]}";
echo "Static access: {$user::class}";

// Несколько интерполяций подряд в одной строке
echo "$name has $arr[key] as value and calls {$user->getName()}";

// Экранированный доллар не должен интерполироваться
echo "Price: \$100, not a variable: \$name";

// Одинокий доллар, за которым не следует идентификатор - тоже не переменная
echo "Just a $ sign";

// Строка, вообще не содержащая интерполяции
echo "Plain string with no variables at all";

// Вложенные фигурные скобки внутри интерполяции
echo "Nested: {$arr['a' . 'b']}";
echo "Method with args: {$obj->method($x, $y)}";

// Индексация переменной в {$...}
echo "Var index: {$arr[$i + 1]}";
echo "Expr index: {$arr[foo()]}";

// Цепочки методов
echo "Chain: {$obj->a()->b()->c()}";

// Статический вызов
echo "Static: {$class::method()}";
echo "Static prop: {$class::$prop}";
echo "Const: {$class::CONST}";

// Вложенные строки внутри {$...}
echo "Nested string: {$arr["key"]}";
echo "Nested string 2: {$arr['key']}";

// Вложенная интерполяция внутри {$...}
echo "Nested interp: {$arr["$key"]}";

// Арифметика и операторы
echo "Arith: {$a + $b}";
echo "Ternary: {$a ? 'y' : 'n'}";
echo "Null coalesce: {$a ?? 'default'}";

// Скобки и группировка
echo "Group: {($a)}";
echo "Func call: {foo($a)}";

// Граничные случаи
echo "Empty braces: {}";           // это НЕ интерполяция, просто текст
echo "Just brace: {";              // текст
echo "Unclosed: {$name";

// экранирование внутри {$...}
echo "Escaped dollar: {\$name}";   // не интерполяция
echo "Escaped brace: \{$name}";

// Комбинированное
echo "Mix: $a {$b->c()} $d[key] {$e['f']}";

// Строки с разными кавычками
echo 'single $name';               // НЕ интерполируется
echo 'single {$name}';             // НЕ интерполируется
echo "double $name";               // интерполируется
echo "double {$name}";             // интерполируется