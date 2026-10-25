<?php // OK: переменная-переменная
$name = 'x';
$$name = 5;
$$$name = 6;
${'a' . 'b'} = 7;
echo $$name, ${$name};
$obj->$name = 1;
$obj->{'p' . 1} = 2;
$$name[0] = 3;
A::$$name = 4;
$cls::$field = 1;
