<?php // OK: var, static в разном порядке с модификатором
class OldStyle {
    var $legacy;
    public static $counter = 0;
    static public $other = 1;
}
