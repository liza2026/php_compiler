<?php // FAIL (line 2, parse): catch без try
catch (Exception $e) {
    echo "no matching try";
}
