<?php // OK: альтернативный синтаксис if: ... endif;
if ($x > 0):
    echo "positive";
elseif ($x < 0):
    echo "negative";
else:
    echo "zero";
endif;
