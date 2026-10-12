<?php // FAIL (line 4, parse): нет двоеточия после default в switch
switch ($x) {
    default
        echo "x";
}
