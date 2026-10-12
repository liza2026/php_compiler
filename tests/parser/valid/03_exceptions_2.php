<?php // OK: несколько типов в одном catch и несколько catch подряд
try {
    risky();
} catch (TypeError | ValueError $e) {
    echo "caught";
} catch (Exception $e) {
    echo "other";
}
