    /* не поддерживаем сканирование нескольких файлов */
%option noyywrap
    /* не вводим тексты с клавиатуры */
%option never-interactive
    /* автоматическое отслеживание номера строки */
%option yylineno
    /* ключевые слова, приведения типов и 0X/E в числах - без учёта регистра */
%option case-insensitive
    /* стек состояний: строки и вставки {$ ... } вкладываются друг в друга */
%option stack


%{
    #include <string>
    #include <cstdlib>  // strtoll
    #include <cerrno>   // для макроса errno
    #include <vector>
    #include "core/helpers/Console.h"
    #include "core/helpers/Buffer.h"
    using std::string;

    std::string formatDouble(double value);
    std::string stripUnderscores(const std::string& text);
    bool isBigInteger(const std::string& digits, int base);
    double calcBigInteger(const std::string& digits, int base);
%}


/* Состояния
   INITIAL       - PHP-код
   NOPHP         - вне PHP-кода (HTML)
   IN_CURLY      - код внутри вставки {$ ... } или ${ ... } в строке; правила те же, что в INITIAL,
                   отличаются только { и } (так без счётчика скобок видно, какая } закрывает вставку)
   COMMENT       - многострочный комментарий
   LINE_COMMENT  - комментарий до конца строки (// или #)
   MEMBER        - имя после ->, ?-> и :: (допустимо любое слово, даже ключевое)
   STRING_S      - '...'
   STRING_D      - "..."
   INTERP_INDEX  - [ключ] после $var внутри "..."
   INTERP_PROP   - ->свойство после $var внутри "..." */

%s IN_CURLY
%x NOPHP
%x COMMENT
%x LINE_COMMENT
%x MEMBER
%x STRING_S
%x STRING_D
%x INTERP_INDEX
%x INTERP_PROP


/* Макросы */

DIGIT       [0-9]
DIGITS      {DIGIT}(_?{DIGIT})*
EXPONENT    e[+-]?{DIGITS}

LABEL       [A-Za-z_\x80-\xff][A-Za-z0-9_\x80-\xff]*
VARIABLE    \${LABEL}

INTEGER      [1-9]{DIGIT}*(_{DIGIT}+)*|0
INT_DEC      [1-9](_?{DIGIT})*|0
INT_HEX      0x[0-9a-f](_?[0-9a-f])*
INT_BIN      0b[01](_?[01])*
INT_OCT_NEW  0[oO][0-7](_?[0-7])*
INT_OCT_OLD  0(_?[0-7])+
FLOAT        ({DIGITS}\.{DIGITS}?|\.{DIGITS}){EXPONENT}?|{DIGITS}{EXPONENT}
NUMBER_ANY   {FLOAT}|{INT_HEX}|{INT_BIN}|{INT_OCT_NEW}|{INT_OCT_OLD}|{INTEGER}

NAME_QUALIFIED         {LABEL}(\\{LABEL})+
NAME_FULLY_QUALIFIED   \\{LABEL}(\\{LABEL})*
NAME_RELATIVE          namespace(\\{LABEL})+

    /* текст в "...": любой символ, кроме " \ $ {, и экранированная пара */
STRING_TEXT (\\(.|\n)|[^"\\${])+

%%

%{
    static bool started = false;   // файл начинается с HTML, а не с PHP-кода
    static Buffer commentBuf;
    static Buffer stringBuf;
    /* Сколько "{" открыто внутри текущей {$...} (чтобы "}" не закрыла её раньше времени) */
    static std::vector<int> exprDepth;

    if (!started) {
        started = true;
        BEGIN(NOPHP);
    }
%}


    /*  Вне PHP-кода */
<NOPHP>"<?php" {
    Console::Log("OpenTag: <?php");
    BEGIN(INITIAL);
}
<NOPHP>"<?=" {
    Console::Log("OpenTagEcho: <?=");
    BEGIN(INITIAL);
}
<NOPHP>([^<]|"<"[^?<])+|"<" {
    Console::Log("HTML text: \"" + string(yytext) + "\"");
}
<NOPHP><<EOF>> { yyterminate(); }

    /* внутри {$ ... } это не закрывающий тег, а обычные ? и > */
<IN_CURLY>"?>" {
    yyless(1);
    Console::Log("Operator: ?");
}

"?>" {
    Console::Log("CloseTag: ?>");
    BEGIN(NOPHP);
}


    /* внутри вставки {$ ... } каждая { открывает вложенное состояние, а } закрывает его */
<IN_CURLY>"{" {
    Console::Log("Separator: {");
    exprDepth.back()++;
}
<IN_CURLY>"}" {
    if (exprDepth.back() > 0) {
        exprDepth.back()--;
        Console::Log("Separator: }");
    } else {
        Console::Log("InterpolationEnd: }");
        exprDepth.pop_back();
        yy_pop_state();
    }
}


    /* Ключевые слова */
abstract        { Console::Log("Keyword: abstract"); }
array           { Console::Log("Keyword: array"); }
as              { Console::Log("Keyword: as"); }
break           { Console::Log("Keyword: break"); }
callable        { Console::Log("Keyword: callable"); }
case            { Console::Log("Keyword: case"); }
catch           { Console::Log("Keyword: catch"); }
class           { Console::Log("Keyword: class"); }
clone           { Console::Log("Keyword: clone"); }
const           { Console::Log("Keyword: const"); }
continue        { Console::Log("Keyword: continue"); }
declare         { Console::Log("Keyword: declare"); }
default         { Console::Log("Keyword: default"); }
do              { Console::Log("Keyword: do"); }
echo            { Console::Log("Keyword: echo"); }
else            { Console::Log("Keyword: else"); }
elseif          { Console::Log("Keyword: elseif"); }
empty           { Console::Log("Keyword: empty"); }
enddeclare      { Console::Log("Keyword: enddeclare"); }
endfor          { Console::Log("Keyword: endfor"); }
endforeach      { Console::Log("Keyword: endforeach"); }
endif           { Console::Log("Keyword: endif"); }
endswitch       { Console::Log("Keyword: endswitch"); }
endwhile        { Console::Log("Keyword: endwhile"); }
enum            { Console::Log("Keyword: enum"); }
eval            { Console::Log("Keyword: eval"); }
exit|die        { Console::Log("Keyword: exit"); }
extends         { Console::Log("Keyword: extends"); }
final           { Console::Log("Keyword: final"); }
finally         { Console::Log("Keyword: finally"); }
fn              { Console::Log("Keyword: fn"); }
for             { Console::Log("Keyword: for"); }
foreach         { Console::Log("Keyword: foreach"); }
function        { Console::Log("Keyword: function"); }
global          { Console::Log("Keyword: global"); }
goto            { Console::Log("Keyword: goto"); }
if              { Console::Log("Keyword: if"); }
implements      { Console::Log("Keyword: implements"); }
include         { Console::Log("Keyword: include"); }
include_once    { Console::Log("Keyword: include_once"); }
instanceof      { Console::Log("Keyword: instanceof"); }
insteadof       { Console::Log("Keyword: insteadof"); }
interface       { Console::Log("Keyword: interface"); }
isset           { Console::Log("Keyword: isset"); }
list            { Console::Log("Keyword: list"); }
match           { Console::Log("Keyword: match"); }
namespace       { Console::Log("Keyword: namespace"); }
new             { Console::Log("Keyword: new"); }
print           { Console::Log("Keyword: print"); }
private         { Console::Log("Keyword: private"); }
protected       { Console::Log("Keyword: protected"); }
public          { Console::Log("Keyword: public"); }
readonly        { Console::Log("Keyword: readonly"); }
require         { Console::Log("Keyword: require"); }
require_once    { Console::Log("Keyword: require_once"); }
return          { Console::Log("Keyword: return"); }
static          { Console::Log("Keyword: static"); }
switch          { Console::Log("Keyword: switch"); }
throw           { Console::Log("Keyword: throw"); }
trait           { Console::Log("Keyword: trait"); }
try             { Console::Log("Keyword: try"); }
unset           { Console::Log("Keyword: unset"); }
use             { Console::Log("Keyword: use"); }
var             { Console::Log("Keyword: var"); }
while           { Console::Log("Keyword: while"); }
yield           { Console::Log("Keyword: yield"); }
yield[ \t\r\n]+from { Console::Log("Keyword: yield from"); }

    /* Ключевые слова, являющиеся операторами */
and             { Console::Log("Operator: and"); }
or              { Console::Log("Operator: or"); }
xor             { Console::Log("Operator: xor"); }

    /* Константы */
true            { Console::Log("Boolean: true"); }
false           { Console::Log("Boolean: false"); }
null            { Console::Log("Null: null"); }
__(line|file|dir|function|class|method|namespace|trait)__ {
    Console::Log("MagicConstant: " + string(yytext));
}

    /* Приведения типов: (int) (string) ... */
"("[ \t]*(int|integer)[ \t]*")"     { Console::Log("Cast: (int)"); }
"("[ \t]*(float|double)[ \t]*")"    { Console::Log("Cast: (float)"); }
"("[ \t]*(string|binary)[ \t]*")"   { Console::Log("Cast: (string)"); }
"("[ \t]*array[ \t]*")"             { Console::Log("Cast: (array)"); }
"("[ \t]*object[ \t]*")"            { Console::Log("Cast: (object)"); }
"("[ \t]*(bool|boolean)[ \t]*")"    { Console::Log("Cast: (bool)"); }


    /* Операторы */
"..."   { Console::Log("Operator: ..."); }
"**="   { Console::Log("Operator: **="); }
"<=>"   { Console::Log("Operator: <=>"); }
"??="   { Console::Log("Operator: ?" "?="); }
"==="   { Console::Log("Operator: ==="); }
"!=="   { Console::Log("Operator: !=="); }
"=="    { Console::Log("Operator: =="); }
"!="|"<>" { Console::Log("Operator: !="); }
"<="    { Console::Log("Operator: <="); }
">="    { Console::Log("Operator: >="); }
"&&"    { Console::Log("Operator: &&"); }
"||"    { Console::Log("Operator: ||"); }
"??"    { Console::Log("Operator: ??"); }
"=>"    { Console::Log("Operator: =>"); }
"++"    { Console::Log("Operator: ++"); }
"--"    { Console::Log("Operator: --"); }
"**"    { Console::Log("Operator: **"); }
"+="    { Console::Log("Operator: +="); }
"-="    { Console::Log("Operator: -="); }
"*="    { Console::Log("Operator: *="); }
"/="    { Console::Log("Operator: /="); }
".="    { Console::Log("Operator: .="); }
"%="    { Console::Log("Operator: %="); }
"&="    { Console::Log("Operator: &="); }
"|="    { Console::Log("Operator: |="); }
"^="    { Console::Log("Operator: ^="); }
"<<="   { Console::Log("Operator: <<="); }
">>="   { Console::Log("Operator: >>="); }
"<<"    { Console::Log("Operator: <<"); }
">>"    { Console::Log("Operator: >>"); }

    /* Односимвольные операторы и разделители */
[-+*/%.=<>!?&|^~@] {
    Console::Log("Operator: " + string(yytext));
}
[()\[\],;:\\] {
    Console::Log("Separator: " + string(yytext));
}
"$" {
    Console::Log("Dollar: $");
}
"{" {
    Console::Log("Separator: {");
}
"}" {
    Console::Log("Separator: }");
}
"#[" {
    Console::Log("AttributeOpen: #[");
}


    /* Обращение к члену класса: после -> ?-> :: идёт имя, даже ключевое слово */
"->" {
    Console::Log("Operator: ->");
    yy_push_state(MEMBER);
}
"?->" {
    Console::Log("Operator: ?->");
    yy_push_state(MEMBER);
}
"::" {
    Console::Log("Operator: ::");
    yy_push_state(MEMBER);
}

<MEMBER>{LABEL} {
    Console::Log("Identifier: " + string(yytext));
    yy_pop_state();
}
<MEMBER>[ \t\r\n]+ { }
<MEMBER>. {
    yyless(0);
    yy_pop_state();
}
<MEMBER><<EOF>> {
    yy_pop_state();
}


    /* Идентификаторы и переменные */
    /* ключевые слова выше: при равной длине побеждает правило, написанное раньше */
{LABEL} {
    Console::Log("Identifier: " + string(yytext));
}
{NAME_RELATIVE} {
    Console::Log("Identifier (relative): " + string(yytext));
}
{NAME_QUALIFIED} {
    Console::Log("Identifier (qualified): " + string(yytext));
}
{NAME_FULLY_QUALIFIED} {
    Console::Log("Identifier (fully qualified): " + string(yytext));
}
{VARIABLE} {
    Console::Log("Variable: " + string(yytext));
}
\$[0-9][A-Za-z0-9_]* {
    Console::Error("Invalid variable name '" + string(yytext) + "' at line " + std::to_string(yylineno));
}


    /* Числовые константы */
{FLOAT} {
    double value = std::strtod(stripUnderscores(yytext).c_str(), nullptr);
    Console::Log("Float: " + formatDouble(value));
}
{INT_HEX} {
    std::string int_str = stripUnderscores(yytext).substr(2);
    if (isBigInteger(int_str, 16)) {
        double value = calcBigInteger(int_str, 16);
        Console::Log("Float: " + formatDouble(value));
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 16);
        Console::Log("Integer (hex): " + std::to_string(value));
    }
}
{INT_BIN} {
    std::string int_str = stripUnderscores(yytext).substr(2);
    if (isBigInteger(int_str, 2)) {
        double value = calcBigInteger(int_str, 2);
        Console::Log("Float: " + formatDouble(value));
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 2);
        Console::Log("Integer (binary): " + std::to_string(value));
    }
}
{INT_OCT_NEW} {
    std::string int_str = stripUnderscores(yytext).substr(2);
    if (isBigInteger(int_str, 8)) {
        double value = calcBigInteger(int_str, 8);
        Console::Log("Float: " + formatDouble(value));
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 8);
        Console::Log("Integer (octal): " + std::to_string(value));
    }
}
{INT_OCT_OLD} {
    std::string int_str = stripUnderscores(yytext).substr(1);
    if (isBigInteger(int_str, 8)) {
        double value = calcBigInteger(int_str, 8);
        Console::Log("Float: " + formatDouble(value));
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 8);
        Console::Log("Integer (octal): " + std::to_string(value));
    }
}
{INTEGER} {
    std::string int_str = stripUnderscores(yytext);
    if (isBigInteger(int_str, 10)) {
        double value = calcBigInteger(int_str, 10);
        Console::Log("Float: " + formatDouble(value));
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 10);
        Console::Log("Integer: " + std::to_string(value));
    }
}
    /* число с мусорным хвостом всегда длиннее корректного числа на том же месте */
({NUMBER_ANY})[A-Za-z0-9_]+ {
    Console::Error("Invalid numeric literal '" + string(yytext) + "' at line " + std::to_string(yylineno));
}


    /*  Комментарии  */
"//"|"#" {
    commentBuf.reset();
    commentBuf.setStartLine(yylineno);
    commentBuf.append(yytext);
    yy_push_state(LINE_COMMENT);
}
<LINE_COMMENT>[^\n?]+|"?" {
    commentBuf.append(yytext);
}
    /* ?> и конец строки в комментарий не входят - возвращаем их во вход */
<LINE_COMMENT>"?>"|\n {
    yyless(0);
    Console::Log("Comment (line " + std::to_string(commentBuf.getStartLine()) + "): " + commentBuf.current());
    yy_pop_state();
}
<LINE_COMMENT><<EOF>> {
    Console::Log("Comment (line " + std::to_string(commentBuf.getStartLine()) + "): " + commentBuf.current());
    yy_pop_state();
}

"/*" {
    commentBuf.reset();
    commentBuf.setStartLine(yylineno);
    yy_push_state(COMMENT);
}
<COMMENT>[^*]+|"*" {
    commentBuf.append(yytext);
}
<COMMENT>"*/" {
    Console::Log("Comment (block, line " + std::to_string(commentBuf.getStartLine()) + "): " + commentBuf.current());
    yy_pop_state();
}
<COMMENT><<EOF>> {
    Console::Error("Unterminated block comment starting at line " + std::to_string(commentBuf.getStartLine()));
    yyterminate();
}


    /* Строки в одинарных кавычках */
\' {
    stringBuf.reset();
    stringBuf.setStartLine(yylineno);
    yy_push_state(STRING_S);
}
<STRING_S>\\[\\'] {
    stringBuf.append(string(1, yytext[1]));
}
<STRING_S>[^'\\]+|\\(.|\n) {
    stringBuf.append(yytext);
}
<STRING_S>\' {
    Console::Log("String literal (line " + std::to_string(stringBuf.getStartLine()) + "): '" + stringBuf.current() + "'");
    stringBuf.reset();
    yy_pop_state();
}
<STRING_S><<EOF>> {
    Console::Error("Unterminated single-quoted string starting at line " + std::to_string(stringBuf.getStartLine()));
    yyterminate();
}


    /* Строки в двойных кавычках
       "a $x b {$y} c" -> StringStart, Fragment "a ", Variable $x, Fragment " b ",
                          InterpolationStart, код, '}', Fragment " c", StringEnd */
\" {
    Console::Log("StringStart (line " + std::to_string(yylineno) + ")");
    stringBuf.reset();
    yy_push_state(STRING_D);
}
<STRING_D>\" {
    if (!stringBuf.current().empty()) {
        yyless(0);
        Console::Log("StringFragment: \"" + stringBuf.current() + "\"");
        stringBuf.reset();
    } else {
        Console::Log("StringEnd");
        yy_pop_state();
    }
}

    /* Кусок текста: раскрываем escape-последовательности */
<STRING_D>{STRING_TEXT}|[${] {
    string text;
    for (int i = 0; yytext[i]; i++) {
        if (yytext[i] != '\\' || !yytext[i + 1]) {
            text += yytext[i];
            continue;
        }
        char c = yytext[++i];
        if      (c == 'n') text += '\n';
        else if (c == 't') text += '\t';
        else if (c == 'r') text += '\r';
        else if (c == 'v') text += '\v';
        else if (c == 'f') text += '\f';
        else if (c == 'e') text += '\x1b';
        else if (c == '\\' || c == '$' || c == '"') text += c;
        else if (c >= '0' && c <= '7') {
            int code = 0, n = 0;
            for (; n < 3 && yytext[i] >= '0' && yytext[i] <= '7'; n++, i++)
                code = code * 8 + (yytext[i] - '0');
            i--;
            text += (char) code;
        }
        else if (c == 'x' && isxdigit((unsigned char) yytext[i + 1])) {
            int code = 0, n = 0;
            for (i++; n < 2 && isxdigit((unsigned char) yytext[i]); n++, i++)
                code = code * 16 + (isdigit((unsigned char) yytext[i]) ? yytext[i] - '0' : tolower(yytext[i]) - 'a' + 10);
            i--;
            text += (char) code;
        }
        else { text += '\\'; text += c; }
    }
    stringBuf.append(text);
}

    /* Простые вставки: $x, $x[...], $x->y, $x?->y */
<STRING_D>{VARIABLE}/"[" {
    if (!stringBuf.current().empty()) {
        yyless(0);
        Console::Log("StringFragment: \"" + stringBuf.current() + "\"");
        stringBuf.reset();
    } else {
        Console::Log("Variable: " + string(yytext));
        yy_push_state(INTERP_INDEX);
    }
}
<STRING_D>{VARIABLE}/"->"[A-Za-z_\x80-\xff] {
    if (!stringBuf.current().empty()) {
        yyless(0);
        Console::Log("StringFragment: \"" + stringBuf.current() + "\"");
        stringBuf.reset();
    } else {
        Console::Log("Variable: " + string(yytext));
        yy_push_state(INTERP_PROP);
    }
}
<STRING_D>{VARIABLE}/"?->"[A-Za-z_\x80-\xff] {
    if (!stringBuf.current().empty()) {
        yyless(0);
        Console::Log("StringFragment: \"" + stringBuf.current() + "\"");
        stringBuf.reset();
    } else {
        Console::Log("Variable: " + string(yytext));
        yy_push_state(INTERP_PROP);
    }
}
<STRING_D>{VARIABLE} {
    if (!stringBuf.current().empty()) {
        yyless(0);
        Console::Log("StringFragment: \"" + stringBuf.current() + "\"");
        stringBuf.reset();
    } else {
        Console::Log("Variable: " + string(yytext));
    }
}

<INTERP_INDEX>"[" {
    Console::Log("Separator: [");
}
<INTERP_INDEX>{LABEL} {
    Console::Log("Identifier: " + string(yytext));
}
<INTERP_INDEX>-?{INTEGER} {
    Console::Log("Integer: " + string(yytext));
}
<INTERP_INDEX>{VARIABLE} {
    Console::Log("Variable: " + string(yytext));
}
<INTERP_INDEX>"]" {
    Console::Log("Separator: ]");
    yy_pop_state();
}
<INTERP_INDEX>(.|\n) {
    Console::Error("Unexpected symbol '" + string(yytext) + "' in string offset at line " + std::to_string(yylineno));
    yy_pop_state();
}

<INTERP_PROP>"->" {
    Console::Log("Operator: ->");
}
<INTERP_PROP>"?->" {
    Console::Log("Operator: ?->");
}
<INTERP_PROP>{LABEL} {
    Console::Log("Identifier: " + string(yytext));
    yy_pop_state();
}

    /* Сложные вставки: дальше читаем обычный PHP-код до парной } */
<STRING_D>"{"/"$" {
    if (!stringBuf.current().empty()) {
        yyless(0);
        Console::Log("StringFragment: \"" + stringBuf.current() + "\"");
        stringBuf.reset();
    } else {
        Console::Log("InterpolationStart: {");
        exprDepth.push_back(0);
        yy_push_state(IN_CURLY);
    }
}
<STRING_D>"${" {
    if (!stringBuf.current().empty()) {
        yyless(0);
        Console::Log("StringFragment: \"" + stringBuf.current() + "\"");
        stringBuf.reset();
    } else {
        Console::Log("InterpolationStart: ${");
        exprDepth.push_back(0);
        yy_push_state(IN_CURLY);
    }
}

<STRING_D,INTERP_INDEX,INTERP_PROP><<EOF>> {
    Console::Error("Unterminated double-quoted string at line " + std::to_string(yylineno));
    yyterminate();
}
<IN_CURLY><<EOF>> {
    Console::Error("Unterminated {$...} interpolation at line " + std::to_string(yylineno));
    yyterminate();
}


    /* Прочее */
[ \t\r\n]+ { }

.   {
    Console::Error("Unexpected symbol '" + string(yytext) + "' at line " + std::to_string(yylineno));
}

%%

/* %.14g даёт компактную запись*/
std::string formatDouble(double value) {
    char buf[64];
    std::snprintf(buf, sizeof(buf), "%.14g", value);
    return std::string(buf);
};

std::string stripUnderscores(const std::string& text) {
    std::string result;
    result.reserve(text.size());
    for (char c : text) if (c != '_') result += c;
    return result;
};

bool isBigInteger(const std::string& digits, int base) {
    errno = 0;                                                      // сбрасываем флаг ошибки
    std::strtoll(digits.c_str(), nullptr, base);  // пробуем прочитать как целое
    return errno == ERANGE;
};

double calcBigInteger(const std::string& digits, int base) {
    double result = 0;                                              // не влезло - считаем как дробное
    for (char c : digits) {
        int digit = isdigit((unsigned char)c) ? c - '0' : tolower((unsigned char)c) - 'a' + 10;
        result = result * base + digit;                             // как читаем число слева направо
    }
    return result;
};