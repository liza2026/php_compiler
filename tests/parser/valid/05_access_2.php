<?php // OK: модификаторы у методов
class Point {
    public function getX() { return 1; }
    private function helper() { return 2; }
    protected function shared() { return 3; }
}
