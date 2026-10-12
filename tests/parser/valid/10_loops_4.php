<?php // OK: foreach: значение, ключ => значение, по ссылке, альт. синтаксис
foreach ($arr as $v) {
    echo $v;
}
foreach ($arr as $k => $v) {
    echo $k, $v;
}
foreach ($arr as &$v) {
    $v *= 2;
}
foreach ($arr as $v):
    echo $v;
endforeach;
