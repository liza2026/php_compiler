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
    #include "parser.tab.hpp"
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
    return T_ECHO;
}
<NOPHP>([^<]|"<"[^?<])+|"<" {
    Console::Log("HTML text: \"" + string(yytext) + "\"");
    yylval.str = new std::string(yytext);
    return T_INLINE_HTML;
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
    return ';';
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
abstract        { Console::Log("Keyword: abstract"); return T_ABSTRACT; }
array           { Console::Log("Keyword: array"); return T_ARRAY; }
as              { Console::Log("Keyword: as"); return T_AS; }
break           { Console::Log("Keyword: break"); return T_BREAK; }
callable        { Console::Log("Keyword: callable"); return T_CALLABLE; }
case            { Console::Log("Keyword: case"); return T_CASE; }
catch           { Console::Log("Keyword: catch"); return T_CATCH; }
class           { Console::Log("Keyword: class"); return T_CLASS; }
clone           { Console::Log("Keyword: clone"); return T_CLONE; }
const           { Console::Log("Keyword: const"); return T_CONST; }
continue        { Console::Log("Keyword: continue"); return T_CONTINUE; }
declare         { Console::Log("Keyword: declare"); return T_DECLARE; }
default         { Console::Log("Keyword: default"); return T_DEFAULT; }
do              { Console::Log("Keyword: do"); return T_DO; }
echo            { Console::Log("Keyword: echo"); return T_ECHO; }
else            { Console::Log("Keyword: else"); return T_ELSE; }
elseif          { Console::Log("Keyword: elseif"); return T_ELSEIF; }
empty           { Console::Log("Keyword: empty"); return T_EMPTY; }
enddeclare      { Console::Log("Keyword: enddeclare"); return T_ENDDECLARE; }
endfor          { Console::Log("Keyword: endfor"); return T_ENDFOR; }
endforeach      { Console::Log("Keyword: endforeach"); return T_ENDFOREACH; }
endif           { Console::Log("Keyword: endif"); return T_ENDIF; }
endswitch       { Console::Log("Keyword: endswitch"); return T_ENDSWITCH; }
endwhile        { Console::Log("Keyword: endwhile"); return T_ENDWHILE; }
enum            { Console::Log("Keyword: enum"); return T_ENUM; }
eval            { Console::Log("Keyword: eval"); return T_EVAL; }
exit|die        { Console::Log("Keyword: exit"); return T_EXIT; }
extends         { Console::Log("Keyword: extends"); return T_EXTENDS; }
final           { Console::Log("Keyword: final"); return T_FINAL; }
finally         { Console::Log("Keyword: finally"); return T_FINALLY; }
fn              { Console::Log("Keyword: fn"); return T_FN; }
for             { Console::Log("Keyword: for"); return T_FOR; }
foreach         { Console::Log("Keyword: foreach"); return T_FOREACH; }
function        { Console::Log("Keyword: function"); return T_FUNCTION; }
global          { Console::Log("Keyword: global"); return T_GLOBAL; }
goto            { Console::Log("Keyword: goto"); return T_GOTO; }
if              { Console::Log("Keyword: if"); return T_IF; }
implements      { Console::Log("Keyword: implements"); return T_IMPLEMENTS; }
include         { Console::Log("Keyword: include"); return T_INCLUDE; }
include_once    { Console::Log("Keyword: include_once"); return T_INCLUDE_ONCE; }
instanceof      { Console::Log("Keyword: instanceof"); return T_INSTANCEOF; }
insteadof       { Console::Log("Keyword: insteadof"); return T_INSTEADOF; }
interface       { Console::Log("Keyword: interface"); return T_INTERFACE; }
isset           { Console::Log("Keyword: isset"); return T_ISSET; }
list            { Console::Log("Keyword: list"); return T_LIST; }
match           { Console::Log("Keyword: match"); return T_MATCH; }
namespace       { Console::Log("Keyword: namespace"); return T_NAMESPACE; }
new             { Console::Log("Keyword: new"); return T_NEW; }
print           { Console::Log("Keyword: print"); return T_PRINT; }
private         { Console::Log("Keyword: private"); return T_PRIVATE; }
protected       { Console::Log("Keyword: protected"); return T_PROTECTED; }
public          { Console::Log("Keyword: public"); return T_PUBLIC; }
readonly        { Console::Log("Keyword: readonly"); return T_READONLY; }
require         { Console::Log("Keyword: require"); return T_REQUIRE; }
require_once    { Console::Log("Keyword: require_once"); return T_REQUIRE_ONCE; }
return          { Console::Log("Keyword: return"); return T_RETURN; }
static          { Console::Log("Keyword: static"); return T_STATIC; }
switch          { Console::Log("Keyword: switch"); return T_SWITCH; }
throw           { Console::Log("Keyword: throw"); return T_THROW; }
trait           { Console::Log("Keyword: trait"); return T_TRAIT; }
try             { Console::Log("Keyword: try"); return T_TRY; }
unset           { Console::Log("Keyword: unset"); return T_UNSET; }
use             { Console::Log("Keyword: use"); return T_USE; }
var             { Console::Log("Keyword: var"); return T_VAR; }
while           { Console::Log("Keyword: while"); return T_WHILE; }
yield           { Console::Log("Keyword: yield"); return T_YIELD; }
yield[ \t\r\n]+from { Console::Log("Keyword: yield from"); return T_YIELD_FROM; }

    /* Ключевые слова, являющиеся операторами */
and             { Console::Log("Operator: and"); return T_LOGICAL_AND; }
or              { Console::Log("Operator: or"); return T_LOGICAL_OR; }
xor             { Console::Log("Operator: xor"); return T_LOGICAL_XOR; }

    /* Константы */
true            { Console::Log("Boolean: true"); return T_TRUE; }
false           { Console::Log("Boolean: false"); return T_FALSE; }
null            { Console::Log("Null: null"); return T_NULL; }
__(line|file|dir|function|class|method|namespace|trait)__ {
    Console::Log("MagicConstant: " + string(yytext));
    yylval.str = new std::string(yytext);
    return T_MAGIC_CONST;
}

    /* Приведения типов: (int) (string) ... */
"("[ \t]*(int|integer)[ \t]*")"     { Console::Log("Cast: (int)"); return T_INT_CAST; }
"("[ \t]*(float|double)[ \t]*")"    { Console::Log("Cast: (float)"); return T_DOUBLE_CAST; }
"("[ \t]*(string|binary)[ \t]*")"   { Console::Log("Cast: (string)"); return T_STRING_CAST; }
"("[ \t]*array[ \t]*")"             { Console::Log("Cast: (array)"); return T_ARRAY_CAST; }
"("[ \t]*object[ \t]*")"            { Console::Log("Cast: (object)"); return T_OBJECT_CAST; }
"("[ \t]*(bool|boolean)[ \t]*")"    { Console::Log("Cast: (bool)"); return T_BOOL_CAST; }


    /* Операторы */
    /* Операторы */
"..."   { Console::Log("Operator: ..."); return T_ELLIPSIS; }
"**="   { Console::Log("Operator: **="); return T_POW_EQUAL; }
"<=>"   { Console::Log("Operator: <=>"); return T_SPACESHIP; }
"??="   { Console::Log("Operator: ?" "?="); return T_COALESCE_EQUAL; }
"==="   { Console::Log("Operator: ==="); return T_IS_IDENTICAL; }
"!=="   { Console::Log("Operator: !=="); return T_IS_NOT_IDENTICAL; }
"=="    { Console::Log("Operator: =="); return T_IS_EQUAL; }
"!="|"<>" { Console::Log("Operator: !="); return T_IS_NOT_EQUAL; }
"<="    { Console::Log("Operator: <="); return T_IS_SMALLER_OR_EQUAL; }
">="    { Console::Log("Operator: >="); return T_IS_GREATER_OR_EQUAL; }
"&&"    { Console::Log("Operator: &&"); return T_BOOLEAN_AND; }
"||"    { Console::Log("Operator: ||"); return T_BOOLEAN_OR; }
"??"    { Console::Log("Operator: ??"); return T_COALESCE; }
"=>"    { Console::Log("Operator: =>"); return T_DOUBLE_ARROW; }
"++"    { Console::Log("Operator: ++"); return T_INC; }
"--"    { Console::Log("Operator: --"); return T_DEC; }
"**"    { Console::Log("Operator: **"); return T_POW; }
"+="    { Console::Log("Operator: +="); return T_PLUS_EQUAL; }
"-="    { Console::Log("Operator: -="); return T_MINUS_EQUAL; }
"*="    { Console::Log("Operator: *="); return T_MUL_EQUAL; }
"/="    { Console::Log("Operator: /="); return T_DIV_EQUAL; }
".="    { Console::Log("Operator: .="); return T_CONCAT_EQUAL; }
"%="    { Console::Log("Operator: %="); return T_MOD_EQUAL; }
"&="    { Console::Log("Operator: &="); return T_AND_EQUAL; }
"|="    { Console::Log("Operator: |="); return T_OR_EQUAL; }
"^="    { Console::Log("Operator: ^="); return T_XOR_EQUAL; }
"<<="   { Console::Log("Operator: <<="); return T_SL_EQUAL; }
">>="   { Console::Log("Operator: >>="); return T_SR_EQUAL; }
"<<"    { Console::Log("Operator: <<"); return T_SL; }
">>"    { Console::Log("Operator: >>"); return T_SR; }

    /* Односимвольные операторы и разделители */
[-+*/%.=<>!?&|^~@] {
    Console::Log("Operator: " + string(yytext));
    return yytext[0];
}
[()\[\],;:\\] {
    Console::Log("Separator: " + string(yytext));
    return yytext[0];
}
"$" {
    Console::Log("Dollar: $");
}
"{" {
    Console::Log("Separator: {");
    return '{';
}
"}" {
    Console::Log("Separator: }");
    return '}';
}
"#[" {
    Console::Log("AttributeOpen: #[");
}


    /* Обращение к члену класса: после -> ?-> :: идёт имя, даже ключевое слово */
"->" {
    Console::Log("Operator: ->");
    yy_push_state(MEMBER);
    return T_OBJECT_OPERATOR;
}
"?->" {
    Console::Log("Operator: ?->");
    yy_push_state(MEMBER);
    return T_NULLSAFE_OBJECT_OPERATOR;
}
"::" {
    Console::Log("Operator: ::");
    yy_push_state(MEMBER);
    return T_DOUBLE_COLON;
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
    yylval.str = new std::string(yytext);
    return T_STRING;
}
{NAME_RELATIVE} {
    Console::Log("Identifier (relative): " + string(yytext));
    yylval.str = new std::string(yytext);
    return T_NAME_RELATIVE;
}
{NAME_QUALIFIED} {
    Console::Log("Identifier (qualified): " + string(yytext));
    yylval.str = new std::string(yytext);
    return T_NAME_QUALIFIED;
}
{NAME_FULLY_QUALIFIED} {
    Console::Log("Identifier (fully qualified): " + string(yytext));
    yylval.str = new std::string(yytext);
    return T_NAME_FULLY_QUALIFIED;
}
{VARIABLE} {
    Console::Log("Variable: " + string(yytext));
    yylval.str = new std::string(yytext + 1);
    return T_VARIABLE;
}
\$[0-9][A-Za-z0-9_]* {
    Console::Error("Invalid variable name '" + string(yytext) + "' at line " + std::to_string(yylineno));
}


    /* Числовые константы */
{FLOAT} {
    double value = std::strtod(stripUnderscores(yytext).c_str(), nullptr);
    Console::Log("Float: " + formatDouble(value));
    yylval.dval = value;
    return T_DNUMBER;
}
{INT_HEX} {
    std::string int_str = stripUnderscores(yytext).substr(2);
    if (isBigInteger(int_str, 16)) {
        double value = calcBigInteger(int_str, 16);
        Console::Log("Float: " + formatDouble(value));
        yylval.dval = value;
        return T_DNUMBER;
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 16);
        Console::Log("Integer (hex): " + std::to_string(value));
        yylval.ival = value;
        return T_LNUMBER;
    }
}
{INT_BIN} {
    std::string int_str = stripUnderscores(yytext).substr(2);
    if (isBigInteger(int_str, 2)) {
        double value = calcBigInteger(int_str, 2);
        Console::Log("Float: " + formatDouble(value));
        yylval.dval = value;
        return T_DNUMBER;
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 2);
        Console::Log("Integer (binary): " + std::to_string(value));
        yylval.ival = value;
        return T_LNUMBER;
    }
}
{INT_OCT_NEW} {
    std::string int_str = stripUnderscores(yytext).substr(2);
    if (isBigInteger(int_str, 8)) {
        double value = calcBigInteger(int_str, 8);
        Console::Log("Float: " + formatDouble(value));
        yylval.dval = value;
        return T_DNUMBER;
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 8);
        Console::Log("Integer (octal): " + std::to_string(value));
        yylval.ival = value;
        return T_LNUMBER;
    }
}
{INT_OCT_OLD} {
    std::string int_str = stripUnderscores(yytext).substr(1);
    if (isBigInteger(int_str, 8)) {
        double value = calcBigInteger(int_str, 8);
        Console::Log("Float: " + formatDouble(value));
        yylval.dval = value;
        return T_DNUMBER;
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 8);
        Console::Log("Integer (octal): " + std::to_string(value));
        yylval.ival = value;
        return T_LNUMBER;
    }
}
{INTEGER} {
    std::string int_str = stripUnderscores(yytext);
    if (isBigInteger(int_str, 10)) {
        double value = calcBigInteger(int_str, 10);
        Console::Log("Float: " + formatDouble(value));
        yylval.dval = value;
        return T_DNUMBER;
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 10);
        Console::Log("Integer: " + std::to_string(value));
        yylval.ival = value;
        return T_LNUMBER;
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
    yylval.str = new std::string(stringBuf.current());
    stringBuf.reset();
    yy_pop_state();
    return T_CONSTANT_STRING;
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