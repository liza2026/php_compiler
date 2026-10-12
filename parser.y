%define parse.error verbose
%define parse.trace

%code requires {
    #include <string>
}

%{
#include <cstdio>
#include <string>

int yylex();
extern int yylineno;
void yyerror(const char* msg);
%}

%union {
    long long    ival;
    double       dval;
    std::string* str;
}

/* ---- Токены со значением ---- */
%token <str>  T_VARIABLE T_INLINE_HTML T_CONSTANT_STRING
%token <str>  T_STRING T_NAME_QUALIFIED T_NAME_FULLY_QUALIFIED T_NAME_RELATIVE T_MAGIC_CONST
%token <ival> T_LNUMBER
%token <dval> T_DNUMBER

/* ---- Ключевые слова и константы ---- */
%token T_ECHO T_ARRAY T_TRUE T_FALSE T_NULL
%token T_ABSTRACT T_AS T_BREAK T_CALLABLE T_CASE T_CATCH T_CLASS T_CLONE T_CONST T_CONTINUE
%token T_DECLARE T_DEFAULT T_DO T_ELSE T_ELSEIF T_EMPTY
%token T_ENDDECLARE T_ENDFOR T_ENDFOREACH T_ENDIF T_ENDSWITCH T_ENDWHILE
%token T_ENUM T_EVAL T_EXIT T_EXTENDS T_FINAL T_FINALLY T_FN T_FOR T_FOREACH T_FUNCTION
%token T_GLOBAL T_GOTO T_IF T_IMPLEMENTS T_INCLUDE T_INCLUDE_ONCE T_INSTANCEOF T_INSTEADOF
%token T_INTERFACE T_ISSET T_LIST T_MATCH T_NAMESPACE T_NEW T_PRINT
%token T_PRIVATE T_PROTECTED T_PUBLIC T_READONLY T_REQUIRE T_REQUIRE_ONCE T_RETURN
%token T_STATIC T_SWITCH T_THROW T_TRAIT T_TRY T_UNSET T_USE T_VAR T_WHILE T_YIELD T_YIELD_FROM

/* ---- Приведения типов, обращение к члену класса, атрибуты ---- */
%token T_INT_CAST T_DOUBLE_CAST T_STRING_CAST T_ARRAY_CAST T_OBJECT_CAST T_BOOL_CAST
%token T_OBJECT_OPERATOR T_NULLSAFE_OBJECT_OPERATOR T_DOUBLE_COLON T_ATTRIBUTE

/* ---- Операторы из нескольких символов ---- */
%token T_ELLIPSIS T_DOUBLE_ARROW
%token T_INC T_DEC T_POW
%token T_SPACESHIP T_COALESCE
%token T_IS_EQUAL T_IS_NOT_EQUAL T_IS_IDENTICAL T_IS_NOT_IDENTICAL
%token T_IS_SMALLER_OR_EQUAL T_IS_GREATER_OR_EQUAL
%token T_BOOLEAN_AND T_BOOLEAN_OR
%token T_LOGICAL_AND T_LOGICAL_OR T_LOGICAL_XOR
%token T_SL T_SR
%token T_PLUS_EQUAL T_MINUS_EQUAL T_MUL_EQUAL T_DIV_EQUAL T_CONCAT_EQUAL T_MOD_EQUAL
%token T_POW_EQUAL T_AND_EQUAL T_OR_EQUAL T_XOR_EQUAL T_SL_EQUAL T_SR_EQUAL T_COALESCE_EQUAL

/* ---- Приоритеты: сверху самый слабый, снизу самый сильный ---- */
%left  T_LOGICAL_OR
%left  T_LOGICAL_XOR
%left  T_LOGICAL_AND
%right '=' T_PLUS_EQUAL T_MINUS_EQUAL T_MUL_EQUAL T_DIV_EQUAL T_CONCAT_EQUAL T_MOD_EQUAL
%right T_POW_EQUAL T_AND_EQUAL T_OR_EQUAL T_XOR_EQUAL T_SL_EQUAL T_SR_EQUAL T_COALESCE_EQUAL

/* тернарный ?: и ?? (п. 9) ---- */
%left  '?' ':'
%right T_COALESCE

%left  T_BOOLEAN_OR
%left  T_BOOLEAN_AND
%left  '|'
%left  '^'
%left  '&'
%nonassoc T_IS_EQUAL T_IS_NOT_EQUAL T_IS_IDENTICAL T_IS_NOT_IDENTICAL T_SPACESHIP
%nonassoc '<' T_IS_SMALLER_OR_EQUAL '>' T_IS_GREATER_OR_EQUAL
%left  '.'
%left  T_SL T_SR
%left  '+' '-'
%left  '*' '/' '%'
%right '!'
%precedence T_UNARY
%right T_POW

/* ---- Строки в двойных кавычках: "текст $x {$y}" (п. 7, 12) ---- */
%token <str>  T_ENCAPSED_AND_WHITESPACE T_STRING_VARNAME
%token T_CURLY_OPEN T_DOLLAR_OPEN_CURLY_BRACES

/* ---- Висячий else: else и elseif относятся к ближайшему if (п. 9) ---- */
%precedence T_NOELSE
%precedence T_ELSEIF
%precedence T_ELSE

%start program

%%

/* ---- Программа и операторы ---- */

program : statement_list
        ;

statement_list  : %empty
                | statement_list statement
                ;

statement : ';'
          | expr ';'
          | T_ECHO expr ';'
          | T_INLINE_HTML    { }
          | '{' statement_list '}'
          ;

/* ---- Переменные и доступ к элементу массива ---- */

variable : T_VARIABLE                   { }
         | variable '[' expr ']'
         ;

/* то, чему можно присвоить значение: $a, $a[0], $a[] */
lvalue : variable
       | variable '[' ']'
       ;

/* ---- Выражения ---- */

expr : T_LNUMBER                    { }
     | T_DNUMBER                    { }
     | T_CONSTANT_STRING            { }
     | T_TRUE
     | T_FALSE
     | T_NULL
     | variable
     | array_literal
     | '(' expr ')'
     | assignment
     | incdec
     | unary
     | binary
     ;

assignment : lvalue '='              expr
           | lvalue T_PLUS_EQUAL     expr
           | lvalue T_MINUS_EQUAL    expr
           | lvalue T_MUL_EQUAL      expr
           | lvalue T_DIV_EQUAL      expr
           | lvalue T_CONCAT_EQUAL   expr
           | lvalue T_MOD_EQUAL      expr
           | lvalue T_POW_EQUAL      expr
           | lvalue T_AND_EQUAL      expr
           | lvalue T_OR_EQUAL       expr
           | lvalue T_XOR_EQUAL      expr
           | lvalue T_SL_EQUAL       expr
           | lvalue T_SR_EQUAL       expr
           | lvalue T_COALESCE_EQUAL expr
           ;

incdec : T_INC variable
       | T_DEC variable
       | variable T_INC
       | variable T_DEC
       ;

unary : '-' expr %prec T_UNARY
      | '+' expr %prec T_UNARY
      | '~' expr %prec T_UNARY
      | '@' expr %prec T_UNARY
      | '!' expr
      ;

binary : expr '+' expr
       | expr '-' expr
       | expr '*' expr
       | expr '/' expr
       | expr '%' expr
       | expr T_POW expr
       | expr '.' expr
       | expr T_SL expr
       | expr T_SR expr
       | expr '&' expr
       | expr '|' expr
       | expr '^' expr
       | expr '<' expr
       | expr '>' expr
       | expr T_IS_SMALLER_OR_EQUAL expr
       | expr T_IS_GREATER_OR_EQUAL expr
       | expr T_IS_EQUAL expr
       | expr T_IS_NOT_EQUAL expr
       | expr T_IS_IDENTICAL expr
       | expr T_IS_NOT_IDENTICAL expr
       | expr T_SPACESHIP expr
       | expr T_BOOLEAN_AND expr
       | expr T_BOOLEAN_OR expr
       | expr T_LOGICAL_AND expr
       | expr T_LOGICAL_OR expr
       | expr T_LOGICAL_XOR expr
       ;

/* ---- Массивы: [1, 2], array(1, 2), ['a' => 1] ---- */

array_literal : '[' array_items_opt ']'
              | T_ARRAY '(' array_items_opt ')'
              ;

array_items_opt : %empty
                | array_items
                | array_items ','
                ;

array_items : array_item
            | array_items ',' array_item
            ;

array_item : expr
           | expr T_DOUBLE_ARROW expr
           ;



/* ---- Новые операторы и выражения (дополняют statement и expr выше) ---- */

statement : T_ECHO echo_list ',' expr ';'      /* echo с несколькими значениями (п. 8) */
          | if_statement
          | while_statement
          | do_while_statement
          | for_statement
          | foreach_statement
          | switch_statement
          | T_BREAK optional_expr ';'
          | T_CONTINUE optional_expr ';'
          | T_RETURN optional_expr ';'
          | function_declaration
          ;

expr : T_MAGIC_CONST                { }
     | double_quoted_string
     | name                         /* константа: STDIN, PHP_EOL */
     | function_call
     | T_PRINT expr %prec T_LOGICAL_AND
     | conditional
     | match
     ;

/* ---- Общие вспомогательные правила ---- */

optional_expr : %empty
              | expr
              ;

possible_comma : %empty
               | ','
               ;

/* имя функции или константы: foo, Foo\bar, \foo, namespace\foo */
name : T_STRING                     { }
     | T_NAME_QUALIFIED             { }
     | T_NAME_FULLY_QUALIFIED       { }
     | T_NAME_RELATIVE              { }
     ;

/* ---- Литералы: строки в двойных кавычках (п. 7, 12) ---- */

/* "..." приходит из лексера кусками: '"', текст, вставки, '"';
   строка без вставок - это '"' T_ENCAPSED_AND_WHITESPACE '"' или пустая "" */
double_quoted_string : '"' encaps_list '"'
                     ;

encaps_list : %empty
            | encaps_list T_ENCAPSED_AND_WHITESPACE    { }
            | encaps_list encaps_var
            ;

/* ---- Подстановка значений в строки (п. 12) ---- */

encaps_var : T_VARIABLE                                        { }
           | T_VARIABLE '[' encaps_var_offset ']'              { }
           | T_VARIABLE T_OBJECT_OPERATOR T_STRING             { }
           | T_VARIABLE T_NULLSAFE_OBJECT_OPERATOR T_STRING    { }
           | T_DOLLAR_OPEN_CURLY_BRACES expr '}'
           | T_DOLLAR_OPEN_CURLY_BRACES T_STRING_VARNAME '}'
           | T_DOLLAR_OPEN_CURLY_BRACES T_STRING_VARNAME '[' expr ']' '}'
           | T_CURLY_OPEN variable '}'
           ;

/* ключ в простой вставке "$a[key]", "$a[0]", "$a[-1]", "$a[$i]" */
encaps_var_offset : T_STRING                { }
                  | T_LNUMBER               { }
                  | '-' T_LNUMBER           { }
                  | T_VARIABLE              { }
                  ;

/* ---- Консоль: echo, print, printf/fgets/readline (п. 8) ---- */

/* echo $a; уже есть выше, здесь - echo $a, $b, ...;
   print - выражение (T_PRINT expr в expr); printf, fgets, readline - вызовы функций */
echo_list : expr
          | echo_list ',' expr
          ;

/* ---- Развилки: if/elseif/else, switch, match, ?:, ?? (п. 9) ---- */

if_statement : if_without_else %prec T_NOELSE
             | if_without_else T_ELSE statement
             | alt_if_without_else T_ENDIF ';'
             | alt_if_without_else T_ELSE ':' statement_list T_ENDIF ';'
             ;

if_without_else : T_IF '(' expr ')' statement
                | if_without_else T_ELSEIF '(' expr ')' statement
                ;

/* альтернативный синтаксис: if (...): ... elseif (...): ... else: ... endif; */
alt_if_without_else : T_IF '(' expr ')' ':' statement_list
                    | alt_if_without_else T_ELSEIF '(' expr ')' ':' statement_list
                    ;

switch_statement : T_SWITCH '(' expr ')' '{' case_list '}'
                 | T_SWITCH '(' expr ')' '{' ';' case_list '}'
                 | T_SWITCH '(' expr ')' ':' case_list T_ENDSWITCH ';'
                 | T_SWITCH '(' expr ')' ':' ';' case_list T_ENDSWITCH ';'
                 ;

case_list : %empty
          | case_list T_CASE expr case_separator statement_list
          | case_list T_DEFAULT case_separator statement_list
          ;

/* после case допустимы и ":", и ";" */
case_separator : ':'
               | ';'
               ;

match : T_MATCH '(' expr ')' '{' match_arm_list '}'
      ;

match_arm_list : %empty
               | non_empty_match_arm_list possible_comma
               ;

non_empty_match_arm_list : match_arm
                         | non_empty_match_arm_list ',' match_arm
                         ;

match_arm : match_arm_conditions possible_comma T_DOUBLE_ARROW expr
          | T_DEFAULT possible_comma T_DOUBLE_ARROW expr
          ;

match_arm_conditions : expr
                     | match_arm_conditions ',' expr
                     ;

/* a ? b : c, короткий a ?: b, a ?? b */
conditional : expr '?' expr ':' expr
            | expr '?' ':' expr
            | expr T_COALESCE expr
            ;

/* ---- Циклы: while, do-while, for, foreach (п. 10) ---- */

while_statement : T_WHILE '(' expr ')' statement
                | T_WHILE '(' expr ')' ':' statement_list T_ENDWHILE ';'
                ;

do_while_statement : T_DO statement T_WHILE '(' expr ')' ';'
                   ;

for_statement : T_FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' statement
              | T_FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' ':' statement_list T_ENDFOR ';'
              ;

/* части заголовка for могут быть пустыми и содержать несколько выражений через запятую */
for_exprs : %empty
          | non_empty_for_exprs
          ;

non_empty_for_exprs : expr
                    | non_empty_for_exprs ',' expr
                    ;

foreach_statement : T_FOREACH '(' expr T_AS foreach_variable ')' foreach_body
                  | T_FOREACH '(' expr T_AS foreach_variable T_DOUBLE_ARROW foreach_variable ')' foreach_body
                  ;

foreach_body : statement
             | ':' statement_list T_ENDFOREACH ';'
             ;

/* $v, &$v (по ссылке), [$a, $b] и list($a, $b) (разбор элемента на части) */
foreach_variable : variable
                 | '&' variable
                 | array_literal
                 | T_LIST '(' array_items_opt ')'
                 ;

/* ---- Функции: объявление, параметры, вызов (п. 11) ---- */

function_declaration : T_FUNCTION returns_ref T_STRING '(' parameter_list ')' return_type '{' statement_list '}'    { }
                     ;

/* function &f() - функция возвращает ссылку */
returns_ref : %empty
            | '&'
            ;

parameter_list : %empty
               | non_empty_parameter_list possible_comma
               ;

non_empty_parameter_list : parameter
                         | non_empty_parameter_list ',' parameter
                         ;

/* [тип] [&] [...] $имя [= значение по умолчанию] */
parameter : optional_type is_reference is_variadic T_VARIABLE                 { }
          | optional_type is_reference is_variadic T_VARIABLE '=' expr        { }
          ;

is_reference : %empty
             | '&'
             ;

is_variadic : %empty
            | T_ELLIPSIS
            ;

optional_type : %empty
              | type_expr
              ;

return_type : %empty
            | ':' type_expr
            ;

/* int, ?string, int|float */
type_expr : type
          | '?' type
          | union_type
          ;

union_type : type '|' type
           | union_type '|' type
           ;

/* null, false, true - отдельные ключевые слова, в объединении: int|false, string|null */
type : T_ARRAY
     | T_CALLABLE
     | T_STATIC
     | T_NULL
     | T_FALSE
     | T_TRUE
     | name
     ;

/* foo(1, 2), printf(...), fgets(STDIN) */
function_call : name argument_list
              ;

argument_list : '(' ')'
              | '(' non_empty_argument_list possible_comma ')'
              | '(' T_ELLIPSIS ')'
              ;

non_empty_argument_list : argument
                        | non_empty_argument_list ',' argument
                        ;

/* позиционный, именованный (width: 10) и распаковка (...$args) */
argument : expr
         | T_STRING ':' expr      { }
         | T_ELLIPSIS expr
         ;

%%

void yyerror(const char* msg) {
    fprintf(stderr, "Syntax error at line %d: %s\n", yylineno, msg);
}