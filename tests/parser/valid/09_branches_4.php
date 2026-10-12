<?php // OK: switch: case, default, провал, альтернативный синтаксис
switch ($x) {
    case 1:
    case 2:
        echo "one or two";
        break;
    case "three";
        echo "semicolon after case is allowed";
        break;
    default:
        echo "other";
}
switch ($x):
    case 1:
        echo "alt";
        break;
endswitch;
