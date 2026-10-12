<?php // OK: именованные аргументы, распаковка ... при вызове
function build($width, $height, $color = "red") {
    return [$width, $height, $color];
}
build(width: 10, height: 20, color: "blue");
build(1, color: "green", height: 2);
build(...[1, 2]);
