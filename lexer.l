    /* не поддерживаем сканирование нескольких файлов */
%option noyywrap
    /* не вводим тексты с клавиатуры */
%option never-interactive
    /* автоматическое отслеживание номера строки */
%option yylineno
    /* ключевые слова и 0X/E в числах - без учёта регистра */
%option case-insensitive
    /* стек состояний: строки и вставки {$ ... } вкладываются друг в друга */
%option stack


%{
    #include <string>
    #include <cstdlib>  // strtoll
    #include <cerrno>   // для макроса errno
    #include <vector>
    #include <deque>
    #include "core/helpers/Console.h"
    #include "core/helpers/Buffer.h"
    #include "parser.tab.hpp"
    using std::string;

    /* Flex-функция сканирует один токен, а yylex (в конце файла) сначала отдаёт токены из очереди:
       одно совпадение может породить несколько токенов (строка с вставками - это ( "a" . ($x) . "b" )) */
    #define YY_DECL int scanToken()
    int scanToken();

    struct PendingToken { int token; YYSTYPE value; };
    static std::deque<PendingToken> pendingTokens;

    /* для каждой открытой строки "...": была ли в ней вставка */
    static std::vector<bool> stringHasInterp;
    /* для каждой открытой вставки {$...} или ${...}: сколько "{" открыто внутри и нужна ли "}" парсеру */
    struct Interp { int depth; bool dollarExpr; };
    static std::vector<Interp> interps;

    int lexerErrors = 0;
    int lastToken = 0;

    void pushToken(int token);
    void pushString(int token, const std::string& text);
    int popPending();
    void startInterpolation(Buffer& stringBuf);

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
   INTERP_PROP   - ->свойство после $var внутри "..."
   Строка в двойных кавычках парсеру отдаётся как обычное выражение:
     "abc"            -> CONSTANT_STRING
     "a $x b {$y} c"  -> ( "a " . ( $x ) . " b " . ( $y ) . " c" )
   то есть '"' и фрагменты строк в грамматике не нужны */

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
DOLLAR_NAME \${LABEL}

INTEGER      [1-9]{DIGIT}*(_{DIGIT}+)*|0
INT_DEC      [1-9](_?{DIGIT})*|0
INT_HEX      0x[0-9a-f](_?[0-9a-f])*
INT_BIN      0b[01](_?[01])*
INT_OCT_NEW  0[oO][0-7](_?[0-7])*
INT_OCT_OLD  0(_?[0-7])+
FLOAT        ({DIGITS}\.{DIGITS}?|\.{DIGITS}){EXPONENT}?|{DIGITS}{EXPONENT}
NUMBER_ANY   {FLOAT}|{INT_HEX}|{INT_BIN}|{INT_OCT_NEW}|{INT_OCT_OLD}|{INTEGER}



    /* текст в "...": любой символ, кроме " \ $ {, и экранированная пара */
STRING_TEXT (\\(.|\n)|[^"\\${])+

%%

%{
    static bool started = false;   // файл начинается с HTML, а не с PHP-кода
    static Buffer commentBuf;
    static Buffer stringBuf;

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
    return ECHO;
}
<NOPHP>([^<]|"<"[^?<])+|"<" {
    Console::Log("HTML text: \"" + string(yytext) + "\"");
    yylval.str = new std::string(yytext);
    return INLINE_HTML;
}
<NOPHP><<EOF>> { yyterminate(); }

    /* внутри {$ ... } это не закрывающий тег, а обычные ? и > */
<IN_CURLY>"?>" {
    yyless(1);
    Console::Log("Operator: ?");
    return '?';
}

"?>" {
    Console::Log("CloseTag: ?>");
    BEGIN(NOPHP);
    return ';';
}


    /* внутри вставки {$ ... } каждая { открывает вложенное состояние, а } закрывает его */
<IN_CURLY>"{" {
    Console::Log("Separator: {");
    interps.back().depth++;
    return '{';
}
<IN_CURLY>"}" {
    if (interps.back().depth > 0) {
        interps.back().depth--;
        Console::Log("Separator: }");
        return '}';
    } else {
        Console::Log("InterpolationEnd: }");
        /* у ${выражение} парсер видит '$' '{' выражение '}', у остальных вставок '}' в токены не попадает */
        if (interps.back().dollarExpr) pushToken('}');
        pushToken(')');
        interps.pop_back();
        yy_pop_state();
        return popPending();
    }
}


    /* Ключевые слова */
array           { Console::Log("Keyword: array"); return ARRAY; }
as              { Console::Log("Keyword: as"); return AS; }
break           { Console::Log("Keyword: break"); return BREAK; }
case            { Console::Log("Keyword: case"); return CASE; }
catch           { Console::Log("Keyword: catch"); return CATCH; }
class           { Console::Log("Keyword: class"); return CLASS; }
const           { Console::Log("Keyword: const"); return CONST; }
continue        { Console::Log("Keyword: continue"); return CONTINUE; }
default         { Console::Log("Keyword: default"); return DEFAULT; }
do              { Console::Log("Keyword: do"); return DO; }
echo            { Console::Log("Keyword: echo"); return ECHO; }
else            { Console::Log("Keyword: else"); return ELSE; }
elseif          { Console::Log("Keyword: elseif"); return ELSEIF; }
endfor          { Console::Log("Keyword: endfor"); return ENDFOR; }
endforeach      { Console::Log("Keyword: endforeach"); return ENDFOREACH; }
endif           { Console::Log("Keyword: endif"); return ENDIF; }
endswitch       { Console::Log("Keyword: endswitch"); return ENDSWITCH; }
endwhile        { Console::Log("Keyword: endwhile"); return ENDWHILE; }
extends         { Console::Log("Keyword: extends"); return EXTENDS; }
finally         { Console::Log("Keyword: finally"); return FINALLY; }
fn              { Console::Log("Keyword: fn"); return FN; }
for             { Console::Log("Keyword: for"); return FOR; }
foreach         { Console::Log("Keyword: foreach"); return FOREACH; }
function        { Console::Log("Keyword: function"); return FUNCTION; }
if              { Console::Log("Keyword: if"); return IF; }
instanceof      { Console::Log("Keyword: instanceof"); return INSTANCEOF; }
new             { Console::Log("Keyword: new"); return NEW; }
private         { Console::Log("Keyword: private"); return PRIVATE; }
protected       { Console::Log("Keyword: protected"); return PROTECTED; }
public          { Console::Log("Keyword: public"); return PUBLIC; }
return          { Console::Log("Keyword: return"); return RETURN; }
static          { Console::Log("Keyword: static"); return STATIC; }
switch          { Console::Log("Keyword: switch"); return SWITCH; }
parent          { Console::Log("Keyword: parent"); return PARENT; }
self            { Console::Log("Keyword: self"); return SELF; }
throw           { Console::Log("Keyword: throw"); return THROW; }
try             { Console::Log("Keyword: try"); return TRY; }
use             { Console::Log("Keyword: use"); return USE; }
var             { Console::Log("Keyword: var"); return VAR; }
while           { Console::Log("Keyword: while"); return WHILE; }

    /* Ключевые слова, являющиеся операторами */
and             { Console::Log("Operator: and"); return LOGICAL_AND; }
or              { Console::Log("Operator: or"); return LOGICAL_OR; }
xor             { Console::Log("Operator: xor"); return LOGICAL_XOR; }

    /* Константы */
true            { Console::Log("Boolean: true"); return TRUE; }
false           { Console::Log("Boolean: false"); return FALSE; }
null            { Console::Log("Null: null"); return NULLPTR; }

    /* Операторы */
"..."   { Console::Log("Operator: ..."); return ELLIPSIS; }
"**="   { Console::Log("Operator: **="); return POW_EQUAL; }
"<=>"   { Console::Log("Operator: <=>"); return SPACESHIP; }
"??="   { Console::Log("Operator: ?" "?="); return COALESCE_EQUAL; }
"==="   { Console::Log("Operator: ==="); return IS_IDENTICAL; }
"!=="   { Console::Log("Operator: !=="); return IS_NOT_IDENTICAL; }
"=="    { Console::Log("Operator: =="); return IS_EQUAL; }
"!="|"<>" { Console::Log("Operator: !="); return IS_NOT_EQUAL; }
"<="    { Console::Log("Operator: <="); return IS_SMALLER_OR_EQUAL; }
">="    { Console::Log("Operator: >="); return IS_GREATER_OR_EQUAL; }
"&&"    { Console::Log("Operator: &&"); return BOOLEAN_AND; }
"||"    { Console::Log("Operator: ||"); return BOOLEAN_OR; }
"??"    { Console::Log("Operator: ??"); return COALESCE; }
"=>"    { Console::Log("Operator: =>"); return DOUBLE_ARROW; }
"++"    { Console::Log("Operator: ++"); return INC; }
"--"    { Console::Log("Operator: --"); return DEC; }
"**"    { Console::Log("Operator: **"); return POW; }
"+="    { Console::Log("Operator: +="); return PLUS_EQUAL; }
"-="    { Console::Log("Operator: -="); return MINUS_EQUAL; }
"*="    { Console::Log("Operator: *="); return MUL_EQUAL; }
"/="    { Console::Log("Operator: /="); return DIV_EQUAL; }
".="    { Console::Log("Operator: .="); return CONCAT_EQUAL; }
"%="    { Console::Log("Operator: %="); return MOD_EQUAL; }
"&="    { Console::Log("Operator: &="); return AND_EQUAL; }
"|="    { Console::Log("Operator: |="); return OR_EQUAL; }
"^="    { Console::Log("Operator: ^="); return XOR_EQUAL; }
"<<="   { Console::Log("Operator: <<="); return SL_EQUAL; }
">>="   { Console::Log("Operator: >>="); return SR_EQUAL; }
"<<"    { Console::Log("Operator: <<"); return SL; }
">>"    { Console::Log("Operator: >>"); return SR; }

    /* Односимвольные операторы и разделители */
[-+*/%.=<>!?&|^~@] {
    Console::Log("Operator: " + string(yytext));
    return yytext[0];
}
[()\[\],;:] {
    Console::Log("Separator: " + string(yytext));
    return yytext[0];
}
"$" {
    Console::Log("Dollar: $");
    return '$';
}
"{" {
    Console::Log("Separator: {");
    return '{';
}
"}" {
    Console::Log("Separator: }");
    return '}';
}



    /* Обращение к члену класса: после -> ?-> :: идёт имя, даже ключевое слово */
"->" {
    Console::Log("Operator: ->");
    yy_push_state(MEMBER);
    return OBJECT_OPERATOR;
}
"?->" {
    Console::Log("Operator: ?->");
    yy_push_state(MEMBER);
    return NULLSAFE_OBJECT_OPERATOR;
}
"::" {
    Console::Log("Operator: ::");
    yy_push_state(MEMBER);
    return DOUBLE_COLON;
}

<MEMBER>{LABEL} {
    Console::Log("Identifier: " + string(yytext));
    yylval.str = new std::string(yytext);
    yy_pop_state();
    return ID;
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
    return ID;
}

    /* $имя -> два токена '$' и ID (имя идёт следом из очереди): пробелов между ними быть не может,
       а имя - всегда ID, даже если совпадает с ключевым словом ($class, $if) */
{DOLLAR_NAME} {
    Console::Log("Variable: " + string(yytext));
    pushString(ID, yytext + 1);
    return '$';
}
    /* $$имя, ${выражение}: '$' сам по себе допустим только перед $ или { без пробелов; остальные '$' - ошибка */
"$"/[$\{] {
    Console::Log("Separator: $");
    return '$';
}
\$[0-9][A-Za-z0-9_]* {
    BEGIN(INITIAL);
    Console::Error("Invalid variable name '" + string(yytext) + "' at line " + std::to_string(yylineno));
    lexerErrors++;
    return ERROR;
}


    /* Числовые константы */
{FLOAT} {
    double value = std::strtod(stripUnderscores(yytext).c_str(), nullptr);
    Console::Log("Float: " + formatDouble(value));
    yylval.dval = value;
    return DNUMBER;
}
{INT_HEX} {
    std::string int_str = stripUnderscores(yytext).substr(2);
    if (isBigInteger(int_str, 16)) {
        double value = calcBigInteger(int_str, 16);
        Console::Log("Float: " + formatDouble(value));
        yylval.dval = value;
        return DNUMBER;
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 16);
        Console::Log("Integer (hex): " + std::to_string(value));
        yylval.ival = value;
        return LNUMBER;
    }
}
{INT_BIN} {
    std::string int_str = stripUnderscores(yytext).substr(2);
    if (isBigInteger(int_str, 2)) {
        double value = calcBigInteger(int_str, 2);
        Console::Log("Float: " + formatDouble(value));
        yylval.dval = value;
        return DNUMBER;
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 2);
        Console::Log("Integer (binary): " + std::to_string(value));
        yylval.ival = value;
        return LNUMBER;
    }
}
{INT_OCT_NEW} {
    std::string int_str = stripUnderscores(yytext).substr(2);
    if (isBigInteger(int_str, 8)) {
        double value = calcBigInteger(int_str, 8);
        Console::Log("Float: " + formatDouble(value));
        yylval.dval = value;
        return DNUMBER;
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 8);
        Console::Log("Integer (octal): " + std::to_string(value));
        yylval.ival = value;
        return LNUMBER;
    }
}
{INT_OCT_OLD} {
    std::string int_str = stripUnderscores(yytext).substr(1);
    if (isBigInteger(int_str, 8)) {
        double value = calcBigInteger(int_str, 8);
        Console::Log("Float: " + formatDouble(value));
        yylval.dval = value;
        return DNUMBER;
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 8);
        Console::Log("Integer (octal): " + std::to_string(value));
        yylval.ival = value;
        return LNUMBER;
    }
}
{INTEGER} {
    std::string int_str = stripUnderscores(yytext);
    if (isBigInteger(int_str, 10)) {
        double value = calcBigInteger(int_str, 10);
        Console::Log("Float: " + formatDouble(value));
        yylval.dval = value;
        return DNUMBER;
    }
    else {
        long long value = std::strtoll(int_str.c_str(), nullptr, 10);
        Console::Log("Integer: " + std::to_string(value));
        yylval.ival = value;
        return LNUMBER;
    }
}
    /* число с мусорным хвостом всегда длиннее корректного числа на том же месте */
({NUMBER_ANY})[A-Za-z0-9_]+ {
    BEGIN(INITIAL);
    Console::Error("Invalid numeric literal '" + string(yytext) + "' at line " + std::to_string(yylineno));
    lexerErrors++;
    return ERROR;
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
    BEGIN(INITIAL);
    Console::Error("Unterminated block comment starting at line " + std::to_string(commentBuf.getStartLine()));
    lexerErrors++;
    return ERROR;
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
    return CONSTANT_STRING;
}
<STRING_S><<EOF>> {
    BEGIN(INITIAL);
    Console::Error("Unterminated single-quoted string starting at line " + std::to_string(stringBuf.getStartLine()));
    lexerErrors++;
    return ERROR;
}


    /* Строки в двойных кавычках: без вставок это один токен CONSTANT_STRING, со вставками -
       ( "фрагмент" . ( вставка ) . "фрагмент" ); пустой фрагмент в начале нужен, чтобы результат был строкой */
\" {
    Console::Log("StringStart (line " + std::to_string(yylineno) + ")");
    stringBuf.reset();
    stringBuf.setStartLine(yylineno);
    stringHasInterp.push_back(false);
    yy_push_state(STRING_D);
}
<STRING_D>\" {
    Console::Log("StringEnd");
    bool hasInterp = stringHasInterp.back();
    stringHasInterp.pop_back();
    yy_pop_state();
    if (!hasInterp) {
        Console::Log("String literal (line " + std::to_string(stringBuf.getStartLine()) + "): \"" + stringBuf.current() + "\"");
        pushString(CONSTANT_STRING, stringBuf.current());
    } else {
        if (!stringBuf.current().empty()) {
            pushToken('.');
            pushString(CONSTANT_STRING, stringBuf.current());
        }
        pushToken(')');
    }
    stringBuf.reset();
    return popPending();
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

    /* Простые вставки: $x, $x[...], $x->y, $x?->y -> . ( $x ), . ( $x [ ключ ] ), . ( $x -> y ) */
<STRING_D>{DOLLAR_NAME}/"[" {
    Console::Log("Variable: " + string(yytext));
    startInterpolation(stringBuf);
    pushToken('$');
    pushString(ID, yytext + 1);
    yy_push_state(INTERP_INDEX);
    return popPending();
}
<STRING_D>{DOLLAR_NAME}/"->"[A-Za-z_\x80-\xff] {
    Console::Log("Variable: " + string(yytext));
    startInterpolation(stringBuf);
    pushToken('$');
    pushString(ID, yytext + 1);
    yy_push_state(INTERP_PROP);
    return popPending();
}
<STRING_D>{DOLLAR_NAME}/"?->"[A-Za-z_\x80-\xff] {
    Console::Log("Variable: " + string(yytext));
    startInterpolation(stringBuf);
    pushToken('$');
    pushString(ID, yytext + 1);
    yy_push_state(INTERP_PROP);
    return popPending();
}
<STRING_D>{DOLLAR_NAME} {
    Console::Log("Variable: " + string(yytext));
    startInterpolation(stringBuf);
    pushToken('$');
    pushString(ID, yytext + 1);
    pushToken(')');
    return popPending();
}

<INTERP_INDEX>"[" {
    Console::Log("Separator: [");
    return '[';
}
    /* "$a[key]": некавыченный ключ - это строка 'key', а не константа */
<INTERP_INDEX>{LABEL} {
    Console::Log("String key: " + string(yytext));
    yylval.str = new std::string(yytext);
    return CONSTANT_STRING;
}
<INTERP_INDEX>"-" {
    Console::Log("Operator: -");
    return '-';
}
<INTERP_INDEX>{INTEGER} {
    std::string int_str = stripUnderscores(yytext);
    if (isBigInteger(int_str, 10)) {
        // как в PHP: слишком большое число в "$a[...]" - это строковый ключ
        Console::Log("String key: " + string(yytext));
        yylval.str = new std::string(yytext);
        return CONSTANT_STRING;
    }
    long long value = std::strtoll(int_str.c_str(), nullptr, 10);
    Console::Log("Integer: " + std::to_string(value));
    yylval.ival = value;
    return LNUMBER;
}
<INTERP_INDEX>{DOLLAR_NAME} {
    Console::Log("Variable: " + string(yytext));
    pushString(ID, yytext + 1);
    return '$';
}
<INTERP_INDEX>"]" {
    Console::Log("Separator: ]");
    yy_pop_state();
    pushToken(']');
    pushToken(')');
    return popPending();
}
<INTERP_INDEX>(.|\n) {
    BEGIN(INITIAL);
    Console::Error("Unexpected symbol '" + string(yytext) + "' in string offset at line " + std::to_string(yylineno));
    lexerErrors++;
    return ERROR;
}

<INTERP_PROP>"->" {
    Console::Log("Operator: ->");
    return OBJECT_OPERATOR;
}
<INTERP_PROP>"?->" {
    Console::Log("Operator: ?->");
    return NULLSAFE_OBJECT_OPERATOR;
}
<INTERP_PROP>{LABEL} {
    Console::Log("Identifier: " + string(yytext));
    yy_pop_state();
    pushString(ID, yytext);
    pushToken(')');
    return popPending();
}

    /* Сложные вставки: дальше читаем обычный PHP-код до парной } */
    /* {$expr} -> . ( $expr ) */
<STRING_D>"{"/"$" {
    Console::Log("InterpolationStart: {");
    startInterpolation(stringBuf);
    interps.push_back({0, false});
    yy_push_state(IN_CURLY);
    return popPending();
}
    /* ${имя} и ${имя[...]} - это переменная $имя */
<STRING_D>"${"{LABEL}/[\[}] {
    Console::Log("InterpolationStart: ${");
    startInterpolation(stringBuf);
    pushToken('$');
    pushString(ID, yytext + 2);
    interps.push_back({0, false});
    yy_push_state(IN_CURLY);
    return popPending();
}
    /* ${выражение} - переменная-переменная: парсер видит '$' '{' выражение '}' */
<STRING_D>"${" {
    Console::Log("InterpolationStart: ${");
    startInterpolation(stringBuf);
    pushToken('$');
    pushToken('{');
    interps.push_back({0, true});
    yy_push_state(IN_CURLY);
    return popPending();
}

<STRING_D,INTERP_INDEX,INTERP_PROP><<EOF>> {
    BEGIN(INITIAL);
    Console::Error("Unterminated double-quoted string at line " + std::to_string(yylineno));
    lexerErrors++;
    return ERROR;
}
<IN_CURLY><<EOF>> {
    BEGIN(INITIAL);
    Console::Error("Unterminated {$...} interpolation at line " + std::to_string(yylineno));
    lexerErrors++;
    return ERROR;
}


    /* Прочее */
[ \t\r\n]+ { }

.   {
    BEGIN(INITIAL);
    Console::Error("Unexpected symbol '" + string(yytext) + "' at line " + std::to_string(yylineno));
    lexerErrors++;
    return ERROR;
}

%%

/* токен без значения - в конец очереди */
void pushToken(int token) {
    PendingToken pending;
    pending.token = token;
    pendingTokens.push_back(pending);
}

/* токен со строковым значением (CONSTANT_STRING, ID) - в конец очереди */
void pushString(int token, const std::string& text) {
    PendingToken pending;
    pending.token = token;
    pending.value.str = new std::string(text);
    pendingTokens.push_back(pending);
}

/* достаёт первый токен очереди и кладёт его значение в yylval */
int popPending() {
    PendingToken pending = pendingTokens.front();
    pendingTokens.pop_front();
    yylval = pending.value;
    return pending.token;
}

/* начало вставки в строке. Первая вставка открывает "(" и отдаёт накопленный фрагмент (возможно, пустой),
   следующие присоединяются через '.'; пустые фрагменты между вставками не нужны */
void startInterpolation(Buffer& stringBuf) {
    if (!stringHasInterp.back()) {
        stringHasInterp.back() = true;
        pushToken('(');
        pushString(CONSTANT_STRING, stringBuf.current());
    } else if (!stringBuf.current().empty()) {
        pushToken('.');
        pushString(CONSTANT_STRING, stringBuf.current());
    }
    stringBuf.reset();
    pushToken('.');
    pushToken('(');
}

/* то, что видит парсер: сначала токены из очереди, затем следующее совпадение лексера */
int yylex() {
    int token = !pendingTokens.empty() ? popPending() : scanToken();
    lastToken = token;
    return token;
}

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