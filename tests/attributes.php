<?php

// Обычные "#"-комментарии - никак не должны путаться с атрибутами
# просто комментарий
#тоже комментарий, без пробела
#

// Атрибут без аргументов
#[Pure]
function noSideEffects() {}

// Атрибут с аргументами
#[Deprecated(reason: 'use foo() instead', since: '8.0')]
function oldFunction() {}

// Несколько атрибутов подряд (каждый в своих #[ ])
#[Attribute]
#[AllowDynamicProperties]
class Foo {}

// Несколько атрибутов через запятую внутри одной группы
#[Route('/home'), Middleware('auth')]
function handler() {}

// Атрибут над параметром функции
function greet(#[SensitiveParameter] string $password) {}

// Атрибут над свойством класса
class User {
    #[Deprecated]
    public string $legacyField;
}

// Атрибут, содержащий вложенный массив как аргумент (важно для
// правильного разбора парных [] и #[ ])
#[Options(['cache' => true, 'ttl' => 60])]
class Cached {}

//пустой атрибут
#[]

// массив без строковых ключей
#[Foo(bar: [1, 2, 3])]

'# not a comment'
"# not a comment"

'#[notAttribute]'
"#[notAttribute]"

// многострочный атрибут
#[
    Foo,
    Bar,
]

//незакрытый атрибут
#[Foo(bar: [1, 2

//атрибут в атрибуте - так нельзя, но лексер должен работать
#[Foo(#[Bar] baz)]