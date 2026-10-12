<?php // FAIL (line 4, parse): пропущена запятая между ветками match
$r = match($x) {
    1 => 'a'
    2 => 'b',
};
