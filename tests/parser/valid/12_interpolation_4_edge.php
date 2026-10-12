<?php // OK: экранирование \$ и \{, одиночный $, подряд несколько {$..}, { с пробелом
echo "$";
echo "Price: 5$";
echo "No interpolation here: \$notavar";
echo "{$a}{$b}{$c}";
echo "brace then space: { $x }";
echo "escaped brace: \{$x}";
