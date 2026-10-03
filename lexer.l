%option noyywrap
%option never-interactive
%option yylineno
%option stack
%{
    #include <string>
    #include <vector>
    #include <cstdlib>
    #include <cstdio>
    #include <cerrno>
    #include <cctype>

    #include "core/helpers/Console.h"
    #include "core/helpers/Buffer.h"

    enum TokenType {
        T_HTML, T_OPEN_TAG, T_OPEN_TAG_ECHO, T_CLOSE_TAG,
        T_COMMENT_LINE, T_COMMENT_BLOCK, T_ATTRIBUTE_OPEN,
        T_KEYWORD, T_BOOLEAN, T_NULL, T_MAGIC_CONSTANT, T_TYPE, T_IDENTIFIER, T_VARIABLE,
        T_OPERATOR, T_CAST, T_DOLLAR, T_NS_SEPARATOR,
        T_LPAREN, T_RPAREN, T_LBRACE, T_RBRACE, T_LBRACKET, T_RBRACKET, T_COMMA, T_SEMICOLON, T_COLON,
        T_INTEGER, T_INTEGER_HEX, T_INTEGER_BIN, T_INTEGER_OCT, T_FLOAT,
        T_STRING_SINGLE, T_STRING_DOUBLE, T_STRING_FRAGMENT,
        T_INTERP_VARIABLE, T_INTERP_ARRAY, T_INTERP_PROPERTY, T_INTERP_DEPRECATED,
        T_INTERP_START, T_INTERP_START_DOLLAR, T_INTERP_END,
        T_ERROR
    };

    struct Token {
        TokenType   type;
        std::string value;   /* текст лексемы или её значение (число, строка без кавычек) */
        int         line;
    };

    /* Названия в том же порядке, что и в enum. "@" - место для номера строки. */
    static const char* const TOKEN_NAMES[] = {
        "HTML text (line @)", "OpenTag", "OpenTagEcho", "CloseTag",
        "Comment (line-style, line @)", "Comment (block, line @)", "AttributeOpen",
        "Keyword", "Boolean", "Null", "MagicConstant", "Type", "Identifier", "Variable",
        "Operator", "Operator (cast)", "Dollar", "NamespaceSeparator",
        "LParen", "RParen", "LBrace", "RBrace", "LBracket", "RBracket", "Comma", "Semicolon", "Colon",
        "Integer", "Integer (hex)", "Integer (binary)", "Integer (octal)", "Float",
        "String (single, line @)", "String (double, line @)", "String fragment (double, line @)",
        "Interpolated variable", "Interpolated variable (array access)",
        "Interpolated variable (property access)", "Interpolated variable (deprecated syntax)",
        "InterpolationStart", "InterpolationStart (dollar-curly)", "InterpolationEnd",
        "Error"
    };

    /* Токен -> строка для лога */
    static std::string describe(const Token& token)
    {
        std::string head = TOKEN_NAMES[token.type];
        std::string text = token.value;

        size_t at = head.find('@');
        if (at != std::string::npos) {          /* HTML, блочный комментарий, строки - с номером строки и в кавычках */
            head.replace(at, 1, std::to_string(token.line));
            char quote = (token.type == T_STRING_SINGLE) ? '\'' : '"';
            text = quote + text + quote;
        }
        return head + ": " + text;
    }

    /* Одна открытая строка в двойных кавычках. Строки бывают вложенными:
       "{$a["key"]}" - внутри вставки открывается ещё одна строка. */
    struct StringFrame {
        int  startLine;
        bool hasInterpolation;   /* были ли вставки ($x, {$x}, ...) */
        int  braceDepth;         /* сколько "{" открыто внутри текущей вставки {$ ... } */
        int  exprLine;           /* строка, на которой началась текущая вставка {$ ... } */
    };
%}

 /* Стартовые условия
    INITIAL      - вне PHP-кода (HTML)
    PHP          - PHP-код; им же разбирается содержимое вставки {$ ... } в строке
    STRING_S     - '...'
    STRING_D     - "..."
    COMMENT      - многострочный комментарий
    LINE_COMMENT - комментарий до конца строки (// или #)
    MEMBER       - имя после -> и ?-> (там допустимо любое слово, даже ключевое) */

%x PHP
%x STRING_S
%x STRING_D
%x COMMENT
%x LINE_COMMENT
%x MEMBER

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

 /* Ключевые слова (без учёта регистра), сгруппированы по смыслу */
KW_CONTROL   if|elseif|else|endif|while|endwhile|do|foreach|endforeach|for|endfor|switch|endswitch|match|case|default|break|continue|return|goto|declare|enddeclare|try|catch|finally|throw|exit|die|yield[ \t\r\n]+from|yield
KW_DECL      function|fn|class|interface|trait|enum|extends|implements|insteadof|namespace|use|const|var|global|public|private|protected|static|abstract|final|readonly
KW_EXPR      as|new|clone|instanceof|echo|print|array|list|isset|unset|empty|and|or|xor
KW_INCLUDE   include_once|include|require_once|require
KEYWORD      (?i:{KW_CONTROL}|{KW_DECL}|{KW_EXPR}|{KW_INCLUDE})

BOOLEAN      (?i:true|false)
NULL_LITERAL (?i:null)
MAGIC_CONST  __(LINE|FILE|DIR|FUNCTION|CLASS|METHOD|NAMESPACE|TRAIT)__

TYPE_NAME    (?i:int|integer|float|double|string|bool|boolean|object|void|mixed|never|iterable|callable|self|parent)

 /* приведение типов: (int) (string) ... */
CAST_TYPE    (?i:int|integer|bool|boolean|float|double|real|string|binary|array|object|unset)
CAST         "("[ \t]*{CAST_TYPE}[ \t]*")"

 /* все операции, кроме -> и ?-> (после них нужно состояние MEMBER) */
OPERATOR     "..."|"**="|"<=>"|"??="|"==="|"!=="|"=="|"!="|"<>"|"<="|">="|"&&"|"||"|"??"|"?:"|"=>"|"::"|"++"|"--"|"**"|"+="|"-="|"*="|"/="|".="|"%="|"&="|"|="|"^="|"<<="|">>="|"<<"|">>"|"+"|"-"|"*"|"/"|"%"|"."|"="|"<"|">"|"!"|"?"|"&"|"|"|"^"|"~"|"@"

 /* Простая интерполяция внутри "...":
    $var, $var[ключ], $var[индекс], $var[$переменная], $var->свойство, ${var} */
SIMPLE_VAR   \$[A-Za-z_][A-Za-z0-9_]*
SIMPLE_IDX   {SIMPLE_VAR}\[[A-Za-z_][A-Za-z0-9_]*\]|{SIMPLE_VAR}\[-?[0-9]+\]|{SIMPLE_VAR}\[{SIMPLE_VAR}\]
SIMPLE_PROP  {SIMPLE_VAR}"->"[A-Za-z_][A-Za-z0-9_]*
DEP_BRACE    \$\{[A-Za-z_][A-Za-z0-9_]*\}


%%

%{
    Buffer buffer;                       /* текст HTML / комментария / куска строки */
    buffer.setStartLine(1);
    std::vector<StringFrame> strings;    /* открытые "..." (внутренняя - последняя) */
    TokenType lastType = T_ERROR;        /* тип последнего токена */

    /* Единственное место, где токен попадает в лог */
    auto emit = [&](TokenType type, const std::string& value, int line = -1) {
        Token token = { type, value, line < 0 ? yylineno : line };
        lastType = type;
        if (type == T_ERROR) Console::Error(token.value);
        else                 Console::Log(describe(token));
    };

    /* Все сообщения об ошибках имеют вид "<что случилось> at line N" */
    auto error = [&](const std::string& message, int line) {
        emit(T_ERROR, message + " at line " + std::to_string(line));
    };

    /* Начать копить новый кусок текста, начинающийся на строке line */
    auto startText = [&](int line) {
        buffer.reset();
        buffer.setStartLine(line);
    };

    /* Если в буфере что-то накопилось - выдать это токеном и очистить буфер */
    auto flushText = [&](TokenType type) {
        if (!buffer.current().empty()) emit(type, buffer.current(), buffer.getStartLine());
        buffer.reset();
    };

    /* Простая вставка ($x, $x[0], $x->y, ${x}): кусок строки до неё, затем сама вставка */
    auto interpolate = [&](TokenType type) {
        flushText(T_STRING_FRAGMENT);
        emit(type, yytext);
        strings.back().hasInterpolation = true;
        startText(yylineno);
    };

    /* Начало сложной вставки ("{" перед $ или "${"): дальше читаем обычный PHP-код до парной "}" */
    auto openExpression = [&](TokenType type) {
        flushText(T_STRING_FRAGMENT);
        emit(type, yytext);
        strings.back().hasInterpolation = true;
        strings.back().braceDepth = 0;
        strings.back().exprLine = yylineno;
        yy_push_state(PHP);
    };

    /* Предыдущий токен - законченный операнд ($x, 5, "a", ], ) ...)? */
    auto lastIsOperand = [&]() {
        switch (lastType) {
            case T_VARIABLE: case T_IDENTIFIER: case T_INTEGER: case T_INTEGER_HEX:
            case T_INTEGER_BIN: case T_INTEGER_OCT: case T_FLOAT:
            case T_BOOLEAN: case T_NULL: case T_MAGIC_CONSTANT:
            case T_STRING_SINGLE: case T_STRING_DOUBLE:
            case T_RBRACKET: case T_RPAREN:
                return true;
            default:
                return false;
        }
    };

    /* %.14g даёт компактную запись */
    auto formatDouble = [](double value) {
        char buf[64];
        std::snprintf(buf, sizeof(buf), "%.14g", value);
        return std::string(buf);
    };

    auto stripUnderscores = [](const std::string& text) {
        std::string result;
        for (char c : text) if (c != '_') result += c;
        return result;
    };

    /* Целое число: digits - цифры без префикса и без "_". Если не влезло в long long -
       PHP делает из него float, считаем как дробное. */
    auto emitInteger = [&](TokenType type, const std::string& digits, int base) {
        errno = 0;
        long long value = std::strtoll(digits.c_str(), nullptr, base);
        if (errno != ERANGE) {
            emit(type, std::to_string(value));
            return;
        }
        double big = 0;
        for (char c : digits) {
            int digit = isdigit((unsigned char)c) ? c - '0' : tolower((unsigned char)c) - 'a' + 10;
            big = big * base + digit;
        }
        emit(T_FLOAT, formatDouble(big));
    };

    /* Символ после "\" в "...": \n \t \r \v \f \e, а для \\ \" \$ - сам символ */
    auto unescape = [](char c) {
        switch (c) {
            case 'n': return '\n';
            case 't': return '\t';
            case 'r': return '\r';
            case 'v': return '\v';
            case 'f': return '\f';
            case 'e': return '\x1b';
            default:  return c;
        }
    };
%}

 /* Вне PHP-кода */

<INITIAL>(?i:"<?php") {
    flushText(T_HTML);
    emit(T_OPEN_TAG, yytext);
    BEGIN(PHP);
}

<INITIAL>"<?=" {
    flushText(T_HTML);
    emit(T_OPEN_TAG_ECHO, yytext);
    BEGIN(PHP);
}

<INITIAL>[^<]+|"<" { buffer.append(yytext); }

<INITIAL><<EOF>> {
    flushText(T_HTML);
    yyterminate();
}


 /* Теги, комментарии, атрибуты */

<PHP>"?>" {
    if (!strings.empty()) {
        /* внутри {$ ... } это не закрывающий тег, а обычные "?" и ">" */
        yyless(1);
        emit(T_OPERATOR, yytext);
    } else {
        emit(T_CLOSE_TAG, yytext);
        startText(yylineno);
        BEGIN(INITIAL);
    }
}

<PHP>"#[" { emit(T_ATTRIBUTE_OPEN, yytext); }

 /* Комментарий до конца строки: // ... и # ... */
<PHP>"//"|"#" {
    startText(yylineno);
    buffer.append(yytext);
    yy_push_state(LINE_COMMENT);
}

<LINE_COMMENT>[^\n?]+|"?" { buffer.append(yytext); }

<LINE_COMMENT>"?>"|\n {
    yyless(0);   /* "?>" и перевод строки в комментарий не входят - возвращаем их во вход */
    emit(T_COMMENT_LINE, buffer.current());
    buffer.reset();
    yy_pop_state();
}

<LINE_COMMENT><<EOF>> {
    emit(T_COMMENT_LINE, buffer.current());
    buffer.reset();
    yy_pop_state();
}

 /* Многострочный комментарий */
<PHP>"/*" {
    startText(yylineno);
    yy_push_state(COMMENT);
}

<COMMENT>[^*]+|"*" { buffer.append(yytext); }

<COMMENT>"*/" {
    emit(T_COMMENT_BLOCK, buffer.current(), buffer.getStartLine());
    buffer.reset();
    yy_pop_state();
}

<COMMENT><<EOF>> {
    error("Unterminated block comment starting", buffer.getStartLine());
    yyterminate();
}


 /* Слова */

<PHP>{KEYWORD}      { emit(T_KEYWORD, yytext); }
<PHP>{BOOLEAN}      { emit(T_BOOLEAN, yytext); }
<PHP>{NULL_LITERAL} { emit(T_NULL, yytext); }
<PHP>{MAGIC_CONST}  { emit(T_MAGIC_CONSTANT, yytext); }
<PHP>{CAST}         { emit(T_CAST, yytext); }
<PHP>{TYPE_NAME}    { emit(T_TYPE, yytext); }
<PHP>{VARIABLE}     { emit(T_VARIABLE, yytext); }

 /* Идентификаторы, в том числе составные: Foo\Bar\Baz, \Fully\Qualified, namespace\Rel.
    Стоит ПОСЛЕ ключевых слов, типов и констант: при равной длине побеждает правило выше */
<PHP>{QUALIFIED}    { emit(T_IDENTIFIER, yytext); }

 /* Одиночный "\" перед "{" - групповой импорт: use App\Models\{Post, Comment};
    {QUALIFIED} до него "дотянуться" не может, поэтому нужен отдельный токен. */
<PHP>"\\" { emit(T_NS_SEPARATOR, yytext); }

 /* Одиночный $ - в $$var (переменная-переменная) и ${expr} */
<PHP>"$" { emit(T_DOLLAR, yytext); }

 /* Имя переменной не может начинаться с цифры ($1abc) */
<PHP>\$[0-9][A-Za-z0-9_]* {
    error("Invalid variable name '" + std::string(yytext) + "'", yylineno);
}

 /* После -> и ?-> идёт имя члена класса (допустимо даже ключевое слово: $a->if) */
<PHP>"?->"|"->" {
    emit(T_OPERATOR, yytext);
    yy_push_state(MEMBER);
}

<MEMBER>{NAME_SEG} {
    emit(T_IDENTIFIER, yytext);
    yy_pop_state();
}

<MEMBER>[ \t\r\n\v\f]+ { /* пробелы между -> и именем допустимы */ }

<MEMBER>. {
    yyless(0);   /* дальше не имя ($o->$name, $o->{...}) - пусть разбирается PHP-режим */
    yy_pop_state();
}

<MEMBER><<EOF>> { yy_pop_state(); }


 /* Операции и пунктуация */

<PHP>{OPERATOR} { emit(T_OPERATOR, yytext); }

<PHP>"("  { emit(T_LPAREN, yytext); }
<PHP>")"  { emit(T_RPAREN, yytext); }
<PHP>"["  { emit(T_LBRACKET, yytext); }
<PHP>"]"  { emit(T_RBRACKET, yytext); }
<PHP>","  { emit(T_COMMA, yytext); }
<PHP>";"  { emit(T_SEMICOLON, yytext); }
<PHP>":"  { emit(T_COLON, yytext); }

 /* Фигурные скобки. Внутри вставки {$ ... } считаем вложенные "{",
    чтобы первая же "}" не закрыла вставку раньше времени */
<PHP>"{" {
    if (!strings.empty()) strings.back().braceDepth++;
    emit(T_LBRACE, yytext);
}

<PHP>"}" {
    if (strings.empty()) {
        emit(T_RBRACE, yytext);                      /* обычный блок кода */
    } else if (strings.back().braceDepth > 0) {
        strings.back().braceDepth--;                 /* закрылась вложенная "{" внутри вставки */
        emit(T_RBRACE, yytext);
    } else {
        emit(T_INTERP_END, yytext);                  /* закрылась сама вставка */
        startText(yylineno);
        yy_pop_state();                              /* назад в текст строки (STRING_D) */
    }
}


 /* Числа */

<PHP>{FLOAT}        { emit(T_FLOAT, formatDouble(std::strtod(stripUnderscores(yytext).c_str(), nullptr))); }
<PHP>{INT_HEX}      { emitInteger(T_INTEGER_HEX, stripUnderscores(yytext + 2), 16); }
<PHP>{INT_BIN}      { emitInteger(T_INTEGER_BIN, stripUnderscores(yytext + 2), 2); }
<PHP>{INT_OCT_NEW}  { emitInteger(T_INTEGER_OCT, stripUnderscores(yytext + 2), 8); }
<PHP>{INT_OCT_OLD}  { emitInteger(T_INTEGER_OCT, stripUnderscores(yytext + 1), 8); }
<PHP>{INTEGER}      { emitInteger(T_INTEGER, stripUnderscores(yytext), 10); }

 /* Число с мусорным хвостом всегда длиннее любого корректного числа на том же месте,
    поэтому побеждает без конфликтов. */
<PHP>{NUMBER_ANY}[A-Za-z0-9_]+ {
    error("Invalid numeric literal '" + std::string(yytext) + "'", yylineno);
}


 /* Строки в одинарных кавычках */

<PHP>\' {
    startText(yylineno);
    yy_push_state(STRING_S);
}

<STRING_S>\\[\\']   { buffer.append(yytext + 1); }      /* экранированные слеш и кавычка - сам символ */
<STRING_S>[^'\\]+   { buffer.append(yytext); }
<STRING_S>\\(.|\n)  { buffer.append(yytext); }          /* прочие последовательности остаются как есть */

<STRING_S>\' {
    emit(T_STRING_SINGLE, buffer.current(), buffer.getStartLine());
    buffer.reset();
    yy_pop_state();
}

<STRING_S><<EOF>> {
    error("Unterminated single-quoted string starting", buffer.getStartLine());
    yyterminate();
}


 /* Строки в двойных кавычках
    Строка "a $x b {$y} c" превращается в последовательность токенов:
        фрагмент "a " | вставка $x | фрагмент " b " | { | ...код... | } | фрагмент " c"
    Если вставок не было - вся строка один токен (T_STRING_DOUBLE).
    Состояние открытой строки хранится в strings.back(). */

<PHP>\" {
    if (!strings.empty() && strings.back().braceDepth == 0 && lastIsOperand()) {
        /* "{$x" - перед кавычкой законченный операнд, значит это не начало новой строки,
           а закрывающая кавычка внешней строки: "}" забыли */
        error("Unterminated {$...} interpolation: missing '}' before closing quote", yylineno);
        yy_pop_state();
        yyless(0);
    } else {
        strings.push_back({ yylineno, false, 0, 0 });
        startText(yylineno);
        yy_push_state(STRING_D);
    }
}

 /* Escape-последовательности */
<STRING_D>\\[ntrvfe\\\"$]       { buffer.append(std::string(1, unescape(yytext[1]))); }
<STRING_D>\\[0-7]{1,3}          { buffer.append(std::string(1, (char)std::strtol(yytext + 1, nullptr, 8))); }
<STRING_D>\\x[0-9A-Fa-f]{1,2}   { buffer.append(std::string(1, (char)std::strtol(yytext + 2, nullptr, 16))); }
<STRING_D>\\(.|\n)              { buffer.append(yytext); }

 /* Простые вставки: каждая - один токен */
<STRING_D>{SIMPLE_IDX}   { interpolate(T_INTERP_ARRAY); }
<STRING_D>{SIMPLE_PROP}  { interpolate(T_INTERP_PROPERTY); }
<STRING_D>{DEP_BRACE}    { interpolate(T_INTERP_DEPRECATED); }
<STRING_D>{SIMPLE_VAR}   { interpolate(T_INTERP_VARIABLE); }

 /* Сложные вставки: дальше читаем обычный PHP-код до парной "}" */
<STRING_D>"{"/"$"        { openExpression(T_INTERP_START); }
<STRING_D>"${"           { openExpression(T_INTERP_START_DOLLAR); }

 /* Обычный текст; одиночные "$" и "{" (не начало вставки) - тоже текст */
<STRING_D>[^"\\${]+ { buffer.append(yytext); }
<STRING_D>[${]      { buffer.append(yytext); }

<STRING_D>\" {
    StringFrame frame = strings.back();
    strings.pop_back();

    if (frame.hasInterpolation)
        flushText(T_STRING_FRAGMENT);       /* хвост после последней вставки (если он не пуст) */
    else
        emit(T_STRING_DOUBLE, buffer.current(), frame.startLine);

    buffer.reset();
    yy_pop_state();
}

<STRING_D><<EOF>> {
    error("Unterminated double-quoted string starting", strings.back().startLine);
    yyterminate();
}


 /* Конец входа в PHP-режиме, пробелы, ошибки */

 /* Конец файла в PHP-режиме. Если мы внутри вставки {$ ... } - она не закрыта */
<PHP><<EOF>> {
    if (!strings.empty())
        error("Unterminated {$...} interpolation starting", strings.back().exprLine);
    yyterminate();
}

<PHP>[ \t\r\n\v\f]+ { /* пробелы между токенами */ }

<PHP>. {
    error("Unexpected symbol '" + std::string(yytext) + "'", yylineno);
}

%%
