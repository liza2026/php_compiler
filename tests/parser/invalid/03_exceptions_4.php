<?php // FAIL (line 4, parse): в catch не указан тип исключения
try {
    f();
} catch ($e) {
}
