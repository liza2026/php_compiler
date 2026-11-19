<?php // OK: методы с телом и без модификаторов, конструктор и деструктор, static
class B extends A {
    private static ?int $count = null;
    function run() {}
    public function __construct(int|string $v = 1) { parent::__construct($v); }
    public function __destruct() {}
    public static function create(): self { return new static(); }
}
