<?php // OK: пустой класс и $this внутри метода
class Empty1 {
}
class Counter {
    public $n = 0;
    function inc() { $this->n++; return $this; }
}
