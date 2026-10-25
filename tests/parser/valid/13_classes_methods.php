<?php // OK: методы с телом и без тела, конструктор и деструктор, интерфейс
interface I extends J, K { const X = 1; public function run(int $a): void; }
abstract class B extends A implements I, J {
    private static ?int $count = null;
    abstract protected function make(): static;
    public function __construct(int|string $v = 1) { parent::__construct($v); }
    public function __destruct() {}
    final public static function create(): self { return new static(); }
}
