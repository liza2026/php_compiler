<?php

namespace App\Services;

use App\Models\User;
use App\Models\{Post, Comment};
use App\Contracts\Repository as RepositoryContract;

// Простое имя (без пространства имён)
$x = new Foo();

// Квалифицированное имя (относительно текущего пространства имён)
$y = new Sub\Foo();

// Полностью квалифицированное имя (от глобального пространства имён)
$z = new \App\Models\User();

// "namespace\..." - имя относительно текущего пространства имён
$w = namespace\Helper::run();
$x = namespace\CONST;
$x = namespace\func();
$x = namespace\Class::method();
$x = new namespace\Class();

// Обращение к статическому члену через полное имя класса
$val = \App\Config::VALUE;

// instanceof с квалифицированным именем
if ($x instanceof \App\Models\User) {
    echo 'yes';
}

class Service extends \App\Base\AbstractService implements \App\Contracts\RepositoryContract
{
}
