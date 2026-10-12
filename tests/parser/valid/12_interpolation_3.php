<?php // OK: сложный синтаксис {$...}: метод, индекс, вложенные строки-ключи
echo "Result: {$obj->method()}";
echo "Nested: {$arr[$key]}";
echo "Quoted key: {$arr['key']}";
echo "Double-quoted key: {$arr["key"]}";
echo "Chain: {$obj->a->b}";
