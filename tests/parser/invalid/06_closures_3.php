<?php // FAIL (line 2, parse): пустой список use ()
$f = function() use () {
    return 1;
};
