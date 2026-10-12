<?php // OK: for(;;), break N / continue N, пустые тела
for (;;) {
    break;
}
for ($i = 0; $i < 3; $i++) {
    for ($j = 0; $j < 3; $j++) {
        if ($j == 1) {
            continue 2;
        }
        if ($i == 2) {
            break 2;
        }
    }
}
while ($x);
foreach ($arr as $v) {}
