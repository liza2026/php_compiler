%option noyywrap
%option never-interactive
%option yylineno
%option stack
%{
    #include <string>
    #include <cstdlib>
    #include <cstdio>
    #include <cctype>
    #include <vector>
    #include <utility>

    #include "core/helpers/Console.h"
    #include "core/helpers/Buffer.h"

    /* Выполняется перед каждым правилом: запоминаем последний непробельный символ
       текущего токена (lastChar) и предыдущего (prevChar) */
    #define YY_USER_ACTION \
        if (yyleng > 0 && !isspace((unsigned char)yytext[yyleng - 1])) { prevChar = lastChar; lastChar = yytext[yyleng - 1]; }
%}

 /* Стартовые условия */

%x PHP
%x STRING_S
%x STRING_D
%x COMMENT
%x LINE_COMMENT
 /* EXPR - сложная интерполяция {$...} внутри строки */
%x EXPR

 /* Именованные шаблоны */

DIGIT        [0-9]
NAME_SEG     [A-Za-z_][A-Za-z0-9_]*
QUALIFIED    \\?{NAME_SEG}(\\{NAME_SEG})*

INTEGER      [1-9]{DIGIT}*(_{DIGIT}+)*|0
INT_HEX      0[xX][0-9a-fA-F](_?[0-9a-fA-F])*
INT_BIN      0[bB][01](_?[01])*
INT_OCT_NEW  0[oO][0-7](_?[0-7])*
INT_OCT_OLD  0(_?[0-7])+
EXPONENT     [eE][+-]?{DIGIT}+
FLOAT        ({DIGIT}(_?{DIGIT})*"."({DIGIT}(_?{DIGIT})*)?|"."{DIGIT}(_?{DIGIT})*){EXPONENT}?|{DIGIT}(_?{DIGIT})*{EXPONENT}

VARIABLE     \$[A-Za-z_][A-Za-z0-9_]*

 /* число с мусорным хвостом */
NUMBER_ANY   {FLOAT}|{INT_HEX}|{INT_BIN}|{INT_OCT_NEW}|{INT_OCT_OLD}|{INTEGER}

CAST_TYPE    (?i:int|integer|bool|boolean|float|double|real|string|binary|array|object|unset)

 /* Простая интерполяция внутри "...":
    $var, $var[ключ], $var[индекс], $var[$переменная], $var->свойство */
SIMPLE_VAR   \$[A-Za-z_][A-Za-z0-9_]*
SIMPLE_IDX   {SIMPLE_VAR}\[[A-Za-z_][A-Za-z0-9_]*\]|{SIMPLE_VAR}\[-?[0-9]+\]|{SIMPLE_VAR}\[{SIMPLE_VAR}\]
SIMPLE_PROP  {SIMPLE_VAR}"->"[A-Za-z_][A-Za-z0-9_]*
DEP_BRACE    \$\{[A-Za-z_][A-Za-z0-9_]*\}


%%

%{
    static Buffer buffer;
    static bool stringHadInterpolation = false; /* была ли уже интерполяция в текущей строке (чтобы не логировать фиктивный пустой "хвост") */
    static int stringStartLine = -1;      /* строка, на которой НАЧАЛАСЬ текущая строка целиком - отдельно от buffer.getStartLine(), которая сбрасывается после каждого фрагмента интерполяции и для сообщения об ошибке "Unterminated" не годится */
    /* Вложенная строка внутри {$arr["key"]} перезаписывает две переменные выше,
       поэтому при открытии строки старые значения кладём сюда, а при закрытии возвращаем. */
    static std::vector<std::pair<int, bool>> savedStrings;
    /* Сколько "{" открыто внутри текущей {$...} (чтобы "}" не закрыла её раньше времени) */
    static std::vector<int> exprDepth;
    /* Нужны, чтобы понять, что перед кавычкой внутри {$...} стоит законченный операнд */
    static char prevChar = 0, lastChar = 0;

    /* %.14g даёт компактную запись*/
    auto formatDouble = [](double value) {
        char buf[64];
        std::snprintf(buf, sizeof(buf), "%.14g", value);
        return std::string(buf);
    };

    auto stripUnderscores = [](const std::string& text) {
        std::string result;
        result.reserve(text.size());
        for (char c : text) if (c != '_') result += c;
        return result;
    };

    /* Превращает цифры целого числа в текст для лога.
       digits - только цифры, без префикса (0x, 0b, 0o) и без "_"
       base   - система счисления: 10, 16, 8 или 2
       label  - подпись, например "Integer: " */
    auto integerText = [](const std::string& digits, int base, const std::string& label) {
        errno = 0;                                                      // сбрасываем флаг ошибки
        long long value = std::strtoll(digits.c_str(), nullptr, base);  // пробуем прочитать как целое
        if (errno != ERANGE) {                                          // влезло - всё хорошо
            return label + std::to_string(value);
        }
        double result = 0;                                              // не влезло - считаем как дробное
        for (char c : digits) {
            int digit = isdigit((unsigned char)c) ? c - '0' : tolower((unsigned char)c) - 'a' + 10;
            result = result * base + digit;                             // как читаем число слева направо
        }
        char text[64];
        std::snprintf(text, sizeof(text), "%.14g", result);
        return std::string("Float: ") + text;
    };
%}

 /* Режим INITIAL */

"<?php" {
    if (!buffer.current().empty()) {
        Console::Log("HTML text (line " + std::to_string(buffer.getStartLine()) + "): \"" + buffer.current() + "\"");
    }
    buffer.reset();
    Console::Log("OpenTag: <?php");
    BEGIN(PHP);
}

"<?=" {
    if (!buffer.current().empty()) {
        Console::Log("HTML text (line " + std::to_string(buffer.getStartLine()) + "): \"" + buffer.current() + "\"");
    }
    buffer.reset();
    Console::Log("OpenTagEcho: <?=");
    BEGIN(PHP);
}

[^<]+ {
    if (buffer.current().empty()) buffer.setStartLine(yylineno);
    buffer.append(yytext);
}

"<" {
    if (buffer.current().empty()) buffer.setStartLine(yylineno);
    buffer.append(yytext);
}

<INITIAL><<EOF>> {
    if (!buffer.current().empty()) {
        Console::Log("HTML text (line " + std::to_string(buffer.getStartLine()) + "): \"" + buffer.current() + "\"");
    }
    yyterminate();
}


 /* Режим PHP: закрывающий тег */

<PHP>"?>" {
    Console::Log("CloseTag: ?>");
    buffer.reset();
    BEGIN(INITIAL);
}

 /* Комментарии (многострочные, однострочные "//" и "#") */

<PHP,EXPR>"#["        { Console::Log("AttributeOpen: #["); }

<PHP,EXPR>"//"|"#" {
    buffer.reset();
    buffer.append(yytext);
    yy_push_state(LINE_COMMENT);
}

<LINE_COMMENT>[^\n?]+  { buffer.append(yytext); }
<LINE_COMMENT>"?"       { buffer.append(yytext); }

<LINE_COMMENT>"?>"|\n {
    yyless(0);   /* "?>" или перевод строки не часть комментария - возвращаем во вход */
    Console::Log("Comment (line-style): " + buffer.current());
    yy_pop_state();
}

<LINE_COMMENT><<EOF>> {
    Console::Log("Comment (line-style): " + buffer.current());
    yy_pop_state();
}

<PHP>"/*" {
    buffer.reset();
    buffer.setStartLine(yylineno);
    BEGIN(COMMENT);
}

<COMMENT>[^*]+ { buffer.append(yytext); }
<COMMENT>"*"   { buffer.append(yytext); }
<COMMENT>"*/" {
    Console::Log("Comment (block, line " + std::to_string(buffer.getStartLine()) + "): \"" + buffer.current() + "\"");
    buffer.reset();
    BEGIN(PHP);
}

<COMMENT><<EOF>> {
    Console::Error("Unterminated block comment starting at line " + std::to_string(buffer.getStartLine()));
    yyterminate();
}

 /* Ключевые слова */

<PHP,EXPR>(?i:if)            { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:elseif)        { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:else)          { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:endif)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:while)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:endwhile)      { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:do)            { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:foreach)       { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:endforeach)    { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:for)           { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:endfor)        { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:as)            { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:function)      { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:fn)            { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:return)        { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:echo)          { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:print)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:break)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:continue)      { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:switch)        { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:endswitch)     { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:match)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:case)          { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:default)       { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:class)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:interface)     { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:trait)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:enum)          { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:extends)       { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:implements)    { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:insteadof)     { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:new)           { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:clone)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:instanceof)    { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:public)        { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:private)       { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:protected)     { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:static)        { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:abstract)      { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:final)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:readonly)      { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:var)           { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:const)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:global)        { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:namespace)     { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:use)           { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:try)           { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:catch)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:finally)       { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:throw)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:array)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:list)          { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:isset)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:unset)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:empty)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:exit)          { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:die)           { Console::Log("Keyword: " + std::string(yytext)); /* die - синоним exit */ }
<PHP,EXPR>(?i:goto)          { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:declare)       { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:enddeclare)    { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:include_once)  { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:include)       { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:require_once)  { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:require)       { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:yield)[ \t\r\n]+(?i:from) { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:yield)         { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:and)           { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:or)            { Console::Log("Keyword: " + std::string(yytext)); }
<PHP,EXPR>(?i:xor)           { Console::Log("Keyword: " + std::string(yytext)); }

<PHP,EXPR>(?i:true)  { Console::Log("Boolean: " + std::string(yytext)); }
<PHP,EXPR>(?i:false) { Console::Log("Boolean: " + std::string(yytext)); }
<PHP,EXPR>(?i:null)  { Console::Log("Null: " + std::string(yytext)); }

 /* Магические константы */
<PHP,EXPR>"__LINE__"      { Console::Log("MagicConstant: __LINE__"); }
<PHP,EXPR>"__FILE__"      { Console::Log("MagicConstant: __FILE__"); }
<PHP,EXPR>"__DIR__"       { Console::Log("MagicConstant: __DIR__"); }
<PHP,EXPR>"__FUNCTION__"  { Console::Log("MagicConstant: __FUNCTION__"); }
<PHP,EXPR>"__CLASS__"     { Console::Log("MagicConstant: __CLASS__"); }
<PHP,EXPR>"__METHOD__"    { Console::Log("MagicConstant: __METHOD__"); }
<PHP,EXPR>"__NAMESPACE__" { Console::Log("MagicConstant: __NAMESPACE__"); }
<PHP,EXPR>"__TRAIT__"     { Console::Log("MagicConstant: __TRAIT__"); }


 /* Приведение типов - (int) (float) (string)  */

<PHP,EXPR>"("[ \t]*{CAST_TYPE}[ \t]*")" { Console::Log("Operator (cast): " + std::string(yytext)); }


 /* Операции */

<PHP,EXPR>"..." { Console::Log("Operator: ..."); }
<PHP,EXPR>"**=" { Console::Log("Operator: **="); }
<PHP,EXPR>"<=>" { Console::Log("Operator: <=>"); }
<PHP,EXPR>"??=" { Console::Log("Operator: ?" "?="); }
<PHP,EXPR>"?->" { Console::Log("Operator: ?" "->"); }
<PHP,EXPR>"===" { Console::Log("Operator: ==="); }
<PHP,EXPR>"!==" { Console::Log("Operator: !=="); }
<PHP,EXPR>"=="  { Console::Log("Operator: =="); }
<PHP,EXPR>"!="  { Console::Log("Operator: !="); }
<PHP,EXPR>"<>"  { Console::Log("Operator: <>"); }
<PHP,EXPR>"<="  { Console::Log("Operator: <="); }
<PHP,EXPR>">="  { Console::Log("Operator: >="); }
<PHP,EXPR>"&&"  { Console::Log("Operator: &&"); }
<PHP,EXPR>"||"  { Console::Log("Operator: ||"); }
<PHP,EXPR>"??"  { Console::Log("Operator: ??"); }
<PHP,EXPR>"?:"  { Console::Log("Operator: ?:"); }
<PHP,EXPR>"->"  { Console::Log("Operator: ->"); }
<PHP,EXPR>"=>"  { Console::Log("Operator: =>"); }
<PHP,EXPR>"::"  { Console::Log("Operator: ::"); }
<PHP,EXPR>"++"  { Console::Log("Operator: ++"); }
<PHP,EXPR>"--"  { Console::Log("Operator: --"); }
<PHP,EXPR>"**"  { Console::Log("Operator: **"); }
<PHP,EXPR>"+="  { Console::Log("Operator: +="); }
<PHP,EXPR>"-="  { Console::Log("Operator: -="); }
<PHP,EXPR>"*="  { Console::Log("Operator: *="); }
<PHP,EXPR>"/="  { Console::Log("Operator: /="); }
<PHP,EXPR>".="  { Console::Log("Operator: .="); }
<PHP,EXPR>"%="  { Console::Log("Operator: %="); }
<PHP,EXPR>"&="  { Console::Log("Operator: &="); }
<PHP,EXPR>"|="  { Console::Log("Operator: |="); }
<PHP,EXPR>"^="  { Console::Log("Operator: ^="); }
<PHP,EXPR>"<<=" { Console::Log("Operator: <<="); }
<PHP,EXPR>">>=" { Console::Log("Operator: >>="); }
<PHP,EXPR>"<<"  { Console::Log("Operator: <<"); }
<PHP,EXPR>">>"  { Console::Log("Operator: >>"); }

<PHP,EXPR>"+" { Console::Log("Operator: +"); }
<PHP,EXPR>"-" { Console::Log("Operator: -"); }
<PHP,EXPR>"*" { Console::Log("Operator: *"); }
<PHP,EXPR>"/" { Console::Log("Operator: /"); }
<PHP,EXPR>"%" { Console::Log("Operator: %"); }
<PHP,EXPR>"." { Console::Log("Operator: ."); }
<PHP,EXPR>"=" { Console::Log("Operator: ="); }
<PHP,EXPR>"<" { Console::Log("Operator: <"); }
<PHP,EXPR>">" { Console::Log("Operator: >"); }
<PHP,EXPR>"!" { Console::Log("Operator: !"); }
<PHP,EXPR>"?" { Console::Log("Operator: ?"); }
<PHP,EXPR>"&" { Console::Log("Operator: &"); }
<PHP,EXPR>"|" { Console::Log("Operator: |"); }
<PHP,EXPR>"^" { Console::Log("Operator: ^"); }
<PHP,EXPR>"~" { Console::Log("Operator: ~"); }
<PHP,EXPR>"@" { Console::Log("Operator: @"); }

 /* Одиночный $ - используется в $$var (переменная-переменная)
    и в устаревшем синтаксисе ${expr} */
<PHP,EXPR>"$" { Console::Log("Dollar: $"); }


 /* Пунктуация */

<PHP,EXPR>"(" { Console::Log("LParen: ("); }
<PHP,EXPR>")" { Console::Log("RParen: )"); }
<PHP,EXPR>"{" {
    if (YY_START == EXPR) exprDepth.back()++;
    Console::Log("LBrace: {");
}
<PHP,EXPR>"}" {
    /* Если мы внутри сложной интерполяции {$...} - эта "}"
       закрывает её и возвращает нас в породившую строку.
       Если мы в обычном PHP-коде - это просто закрывающая
       фигурная скобка блока */
    if (YY_START == EXPR && exprDepth.back() > 0) {
        exprDepth.back()--;
        Console::Log("RBrace: }");
    } else if (YY_START == EXPR) {
        Console::Log("InterpolationEnd: }");
        exprDepth.pop_back();
        yy_pop_state();
    } else {
        Console::Log("RBrace: }");
    }
}
<PHP,EXPR>"[" { Console::Log("LBracket: ["); }
<PHP,EXPR>"]" { Console::Log("RBracket: ]"); }
<PHP,EXPR>"," { Console::Log("Comma: ,"); }
<PHP,EXPR>";" { Console::Log("Semicolon: ;"); }
<PHP,EXPR>":" { Console::Log("Colon: :"); }


 /* Числа */

<PHP,EXPR>{FLOAT} {
    double value = std::strtod(stripUnderscores(yytext).c_str(), nullptr);
    Console::Log("Float: " + formatDouble(value));
}

<PHP,EXPR>{INT_HEX} {
    Console::Log(integerText(stripUnderscores(yytext).substr(2), 16, "Integer (hex): "));
}
<PHP,EXPR>{INT_BIN} {
    Console::Log(integerText(stripUnderscores(yytext).substr(2), 2, "Integer (binary): "));
}
<PHP,EXPR>{INT_OCT_NEW} {
    Console::Log(integerText(stripUnderscores(yytext).substr(2), 8, "Integer (octal): "));
}
<PHP,EXPR>{INT_OCT_OLD} {
    Console::Log(integerText(stripUnderscores(yytext).substr(1), 8, "Integer (octal): "));
}
<PHP,EXPR>{INTEGER} {
    Console::Log(integerText(stripUnderscores(yytext), 10, "Integer: "));
}

 /* Число с мусорным хвостом: 123abc, 0x1Ag, 0b1010xyz, 1.5ex, 5.f00,
    1__000000, 0o_17 ... Всегда длиннее любого корректного числа на
    том же месте, поэтому побеждает без конфликтов. */
<PHP,EXPR>{NUMBER_ANY}[A-Za-z0-9_]+ {
    Console::Error("Invalid numeric literal '" + std::string(yytext) + "' at line " + std::to_string(yylineno));
}

 /* Переменная, имя которой начинается с цифры ($1abc, $1): по правилам
    PHP имя переменной начинается с буквы или подчёркивания. Действует
    только в коде, не внутри "..." (там "$1abc" - просто текст). */
<PHP,EXPR>\$[0-9][A-Za-z0-9_]* {
    Console::Error("Invalid variable name '" + std::string(yytext) + "' at line " + std::to_string(yylineno));
}

 /* Строки в одинарных кавычках */

<PHP,EXPR>\' {
    buffer.reset();
    buffer.setStartLine(yylineno);
    yy_push_state(STRING_S);
}

<STRING_S>\\\\ { buffer.append("\\"); }
<STRING_S>\\\' { buffer.append("'"); }
<STRING_S>[^'\\]+ { buffer.append(yytext); }
<STRING_S>\\(.|\n) { buffer.append(yytext); }

<STRING_S>\' {
    Console::Log("String (single, line " + std::to_string(buffer.getStartLine()) + "): \'" + buffer.current() + "\'");
    buffer.reset();
    yy_pop_state();
}

<STRING_S><<EOF>> {
    Console::Error("Unterminated single-quoted string starting at line " + std::to_string(buffer.getStartLine()));
    yyterminate();
}


 /* Строки в двойных кавычках */

<PHP,EXPR>\" {
    /* Сообщить об ошибке, выйти из {$...} и
       отдать эту же кавычку (yyless(0)) внешней строке, чтобы она закрылась. */
    if (YY_START == EXPR && exprDepth.back() == 0 &&
        (isalnum((unsigned char)prevChar) || prevChar == '_' || prevChar == ']' || prevChar == ')')) {
        Console::Error("Unterminated {$...} interpolation: missing '}' before closing quote at line " + std::to_string(yylineno));
        exprDepth.pop_back();
        yy_pop_state();
        yyless(0);
    } else {
        buffer.reset();
        buffer.setStartLine(yylineno);
        savedStrings.push_back({stringStartLine, stringHadInterpolation});
        stringStartLine = yylineno;
        stringHadInterpolation = false;
        yy_push_state(STRING_D);
    }
}

<STRING_D>\\n  { if (buffer.current().empty()) buffer.setStartLine(yylineno); buffer.append("\n"); }
<STRING_D>\\t  { if (buffer.current().empty()) buffer.setStartLine(yylineno); buffer.append("\t"); }
<STRING_D>\\r  { if (buffer.current().empty()) buffer.setStartLine(yylineno); buffer.append("\r"); }
<STRING_D>\\v  { if (buffer.current().empty()) buffer.setStartLine(yylineno); buffer.append("\v"); }
<STRING_D>\\f  { if (buffer.current().empty()) buffer.setStartLine(yylineno); buffer.append("\f"); }
<STRING_D>\\e  { if (buffer.current().empty()) buffer.setStartLine(yylineno); buffer.append("\x1b"); }
<STRING_D>\\\"         { if (buffer.current().empty()) buffer.setStartLine(yylineno); buffer.append("\""); }
<STRING_D>\\\\ { if (buffer.current().empty()) buffer.setStartLine(yylineno); buffer.append("\\"); }
<STRING_D>\\\$ { if (buffer.current().empty()) buffer.setStartLine(yylineno); buffer.append("$"); }
<STRING_D>\\[0-7]{1,3} {
    if (buffer.current().empty()) buffer.setStartLine(yylineno);
    char c = (char)std::strtol(yytext + 1, nullptr, 8);
    buffer.append(std::string(1, c));
}
<STRING_D>\\x[0-9A-Fa-f]{1,2} {
    if (buffer.current().empty()) buffer.setStartLine(yylineno);
    char c = (char)std::strtol(yytext + 2, nullptr, 16);
    buffer.append(std::string(1, c));
}

<STRING_D>\\(.|\n) { if (buffer.current().empty()) buffer.setStartLine(yylineno); buffer.append(yytext); }

 /* Простая интерполяция: $var, $var[key], $var->prop, ${var} */

<STRING_D>{SIMPLE_IDX} {
    if (!buffer.current().empty()) {
        Console::Log("String fragment (double, line " + std::to_string(buffer.getStartLine()) + "): \"" + buffer.current() + "\"");
        buffer.reset();
    }
    Console::Log("Interpolated variable (array access): " + std::string(yytext));
    stringHadInterpolation = true;
}

<STRING_D>{SIMPLE_PROP} {
    if (!buffer.current().empty()) {
        Console::Log("String fragment (double, line " + std::to_string(buffer.getStartLine()) + "): \"" + buffer.current() + "\"");
        buffer.reset();
    }
    Console::Log("Interpolated variable (property access): " + std::string(yytext));
    stringHadInterpolation = true;
}

<STRING_D>{DEP_BRACE} {
    if (!buffer.current().empty()) {
        Console::Log("String fragment (double, line " + std::to_string(buffer.getStartLine()) + "): \"" + buffer.current() + "\"");
        buffer.reset();
    }
    Console::Log("Interpolated variable (deprecated syntax): " + std::string(yytext));
    stringHadInterpolation = true;
}

<STRING_D>"${" {
    if (!buffer.current().empty()) {
        Console::Log("String fragment (double, line " + std::to_string(buffer.getStartLine()) + "): \"" + buffer.current() + "\"");
        buffer.reset();
    }
    Console::Log("InterpolationStart (dollar-curly): ${");
    stringHadInterpolation = true;
    exprDepth.push_back(0);
    yy_push_state(EXPR);
}

<STRING_D>{SIMPLE_VAR} {
    if (!buffer.current().empty()) {
        Console::Log("String fragment (double, line " + std::to_string(buffer.getStartLine()) + "): \"" + buffer.current() + "\"");
        buffer.reset();
    }
    Console::Log("Interpolated variable: " + std::string(yytext));
    stringHadInterpolation = true;
}

 /* Сложная интерполяция {$...} - произвольное выражение,
    включая $$var (переменная-переменная), $obj->method(),
    $arr[$key]['x'], и т.п. */

<STRING_D>"{"/"$" {
    if (!buffer.current().empty()) {
        Console::Log("String fragment (double, line " + std::to_string(buffer.getStartLine()) + "): \"" + buffer.current() + "\"");
        buffer.reset();
    }
    Console::Log("InterpolationStart: {");
    stringHadInterpolation = true;
    exprDepth.push_back(0);
    yy_push_state(EXPR);
}

<EXPR><<EOF>> {
    Console::Error("Unterminated {$...} interpolation at line " + std::to_string(yylineno));
    yyterminate();
}

<STRING_D>[^"\\${\n]+ {
    if (buffer.current().empty()) buffer.setStartLine(yylineno);
    buffer.append(yytext);
}

<STRING_D>"{" {
    if (buffer.current().empty()) buffer.setStartLine(yylineno);
    buffer.append(yytext);
}

<STRING_D>[$\n] {
    if (buffer.current().empty()) buffer.setStartLine(yylineno);
    buffer.append(yytext);
}

<STRING_D>\" {
    if (!buffer.current().empty() || !stringHadInterpolation) {
        std::string label = stringHadInterpolation ? "String fragment (double" : "String (double";
        Console::Log(label + ", line " + std::to_string(stringStartLine) + "): \"" + buffer.current() + "\"");
    }
    buffer.reset();
    stringStartLine = savedStrings.back().first;
    stringHadInterpolation = savedStrings.back().second;
    savedStrings.pop_back();
    yy_pop_state();
}

<STRING_D><<EOF>> {
    Console::Error("Unterminated double-quoted string starting at line " + std::to_string(stringStartLine));
    yyterminate();
}


 /* Идентификаторы (в т.ч. составные, разделённые "\" - имена
    пространств имён: Foo\Bar\Baz, \Fully\Qualified, namespace\Rel) */

<PHP,EXPR>(?i:int)      { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:integer)  { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:float)    { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:double)   { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:string)   { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:bool)     { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:boolean)  { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:object)   { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:void)     { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:mixed)    { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:never)    { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:iterable) { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:callable) { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:self)     { Console::Log("Type: " + std::string(yytext)); }
<PHP,EXPR>(?i:parent)   { Console::Log("Type: " + std::string(yytext)); }

<PHP,EXPR>{VARIABLE} { Console::Log("Variable: " + std::string(yytext)); }
<PHP,EXPR>{QUALIFIED} { Console::Log("Identifier: " + std::string(yytext)); }

 /* Одиночный "\" перед "{" - используется в групповом импорте
    (PHP 7.0+): use App\Models\{Post, Comment};
    Правило {QUALIFIED} само по себе не может "дотянуться" до этой
    "\", т.к. за ней не следует имя (там сразу "{"), поэтому нужен
    отдельный, более короткий (а значит, применяемый лишь когда
    длинного варианта не нашлось) токен-сепаратор. */
<PHP,EXPR>"\\" { Console::Log("NamespaceSeparator: \\"); }


 /* Пробелы и ошибочные символы */

<PHP,EXPR>[ \t\r\n\v\f]+ { /* игнорируем пробелы внутри PHP-кода */ }

<PHP,EXPR>. {
    Console::Error("Unexpected symbol '" + std::string(yytext) + "' at line " + std::to_string(yylineno));
}

%%
