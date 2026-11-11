<?php // OK: ввод с консоли: fscanf, цикл по fgets(STDIN), readline без аргументов
fscanf(STDIN, "%d", $n);
while (($line = fgets(STDIN)) !== false) {
    echo trim($line), "\n";
}
$in = trim(readline());
