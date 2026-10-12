<?php // FAIL (line 3, compile): два модификатора доступа сразу (ошибка компиляции)
class Point {
    public private $x;
}
