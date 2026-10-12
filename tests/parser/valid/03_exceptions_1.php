<?php // OK: try / catch / finally
try {
    doSomething();
} catch (Exception $e) {
    echo $e;
} finally {
    cleanup();
}
