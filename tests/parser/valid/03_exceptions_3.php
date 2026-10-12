<?php // OK: throw как оператор и catch без переменной (PHP 8)
try {
    throw new Exception("failure");
} catch (Exception) {
    echo "no variable needed since PHP 8";
}
