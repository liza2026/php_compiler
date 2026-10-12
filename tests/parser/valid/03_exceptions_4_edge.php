<?php // OK: пустые тела, try/finally без catch, вложенный try
try {
} catch (Exception $e) {
}
try {
    try {
        f();
    } finally {
    }
} finally {
}
