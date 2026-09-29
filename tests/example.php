<html>
<body>
<?php
// Простой тест лексера
# Ещё один вид однострочного комментария

/*
 Многострочный
 комментарий
*/

class Person {
    public string $name;
    private int $age;

    public function __construct($name, $age) {
        $this->name = $name;
        $this->age = $age;
    }

    public function greet() {
        echo "Hello, $this->name! You are $this->age years old.\n";
    }
}

$name = 'Julia';
$age = 21;
$height = 1.68;
$scores = [10, 20, 30];
$is_valid = true;
$nothing = null;

// Числа в разных системах счисления
$hex = 0x1A;
$binary = 0b1010;
$octalNew = 0o17;
$octalOld = 0755;

// Escape-последовательности по коду символа
$byCode = "A\x41B\101C";

if ($age >= 18) {
    echo "Welcome, " . $name . "\n";

    foreach ($scores as $score) {
        echo "Score: $score\n";
    }
} elseif ($age > 0) {
    echo 'Too young';
} else {
    echo 'Invalid age';
}

$i = 0;
while ($i < 3) {
    $i++;
}

$result = $age + 10 * 2 - 1;
$result **= 2;
$isEqual = ($age === 21);

?>
</body>
</html>
