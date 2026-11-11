<?php // OK: ->, ::, [ ], вызовы и присваивание - операции над expr, любые цепочки
$a[0]->b = 1;
$o->m()->n[1]['k']->p = 2;
Foo::bar()->baz()::QUX;
static::create()->run();
parent::__construct($x);
$x = new Foo(1, 2);
$y = (new Foo)->bar;
$z = new $cls($a);
$f = $o?->m()?->p;
$g = strlen(...);
$h = &$arr[0];
$i = $a & $b;
++$a[0];
$a->b++;
--$o->c;
$v = $o->$name;
$w = $o->{'p' . 1};
if ($a instanceof Foo && !$b instanceof self) {}
