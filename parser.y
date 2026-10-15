%define parse.error verbose
%define parse.trace

%code requires {
    #include <string>
}

%{
#include <cstdio>
#include <string>
#include "core/helpers/Console.h"

int yylex();
extern int yylineno;
void yyerror(const char* msg);
%}

%union {
    long long    ival;
    double       dval;
    std::string* str;
}

%start program

/* Токены */
%token <str>  T_VARIABLE T_INLINE_HTML T_CONSTANT_STRING
%token <str>  T_STRING T_NAME_QUALIFIED T_NAME_FULLY_QUALIFIED T_NAME_RELATIVE T_MAGIC_CONST
%token <str>  T_ENCAPSED_AND_WHITESPACE T_STRING_VARNAME
%token <ival> T_LNUMBER
%token <dval> T_DNUMBER
%token T_ERROR

/* Ключевые слова и константы */
%token T_ECHO T_ARRAY T_TRUE T_FALSE T_NULL
%token T_ABSTRACT T_AS T_BREAK T_CALLABLE T_CASE T_CATCH T_CLASS T_CLONE T_CONST T_CONTINUE
%token T_DECLARE T_DEFAULT T_DO T_ELSE T_ELSEIF T_EMPTY
%token T_ENDDECLARE T_ENDFOR T_ENDFOREACH T_ENDIF T_ENDSWITCH T_ENDWHILE
%token T_ENUM T_EVAL T_EXIT T_EXTENDS T_FINAL T_FINALLY T_FN T_FOR T_FOREACH T_FUNCTION
%token T_GLOBAL T_GOTO T_IF T_IMPLEMENTS T_INCLUDE T_INCLUDE_ONCE T_INSTANCEOF T_INSTEADOF
%token T_INTERFACE T_ISSET T_LIST T_MATCH T_NAMESPACE T_NEW T_PRINT
%token T_PRIVATE T_PROTECTED T_PUBLIC T_READONLY T_REQUIRE T_REQUIRE_ONCE T_RETURN
%token T_STATIC T_SWITCH T_THROW T_TRAIT T_TRY T_UNSET T_USE T_VAR T_WHILE T_YIELD T_YIELD_FROM

/* Приведения типов, обращение к члену класса, атрибуты */
%token T_INT_CAST T_DOUBLE_CAST T_STRING_CAST T_ARRAY_CAST T_OBJECT_CAST T_BOOL_CAST
%token T_OBJECT_OPERATOR T_NULLSAFE_OBJECT_OPERATOR T_DOUBLE_COLON T_ATTRIBUTE

/* Операторы из нескольких символов */
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

/* Части строк в двойных кавычках */
%token T_CURLY_OPEN T_DOLLAR_OPEN_CURLY_BRACES


/* Приоритеты */
%precedence T_THROW T_FN
%left  T_LOGICAL_OR
%left  T_LOGICAL_XOR
%left  T_LOGICAL_AND
%right '=' T_PLUS_EQUAL T_MINUS_EQUAL T_MUL_EQUAL T_DIV_EQUAL T_CONCAT_EQUAL T_MOD_EQUAL
%right T_POW_EQUAL T_AND_EQUAL T_OR_EQUAL T_XOR_EQUAL T_SL_EQUAL T_SR_EQUAL T_COALESCE_EQUAL
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
%nonassoc T_INSTANCEOF
%precedence T_UNARY
%right T_POW

/* висячий else: else и elseif относятся к ближайшему if */
%precedence T_NOELSE
%precedence T_ELSEIF
%precedence T_ELSE


%%

/* Программа и операторы */

program : stmt_list
        ;

stmt_list : %empty
          | stmt_list stmt
          ;

stmt : ';'
     | expr ';'
     | T_INLINE_HTML
     | block
     | echo_stmt
     | if_stmt
     | switch_stmt
     | while_stmt
     | do_while_stmt
     | for_stmt
     | foreach_stmt
     | T_BREAK optional_expr ';'
     | T_CONTINUE optional_expr ';'
     | T_RETURN optional_expr ';'
     | function_declaration
     | try_stmt
     | class_declaration
     ;

block : '{' stmt_list '}'
      ;

/* Переменные и доступ к элементу массива */

/* $a, $a[0], $o->p, $o->m(), $f(1), Foo::$x, Foo::bar() */
variable : T_VARIABLE
         | dereferenceable '[' expr ']'
         | dereferenceable T_OBJECT_OPERATOR member_name
         | dereferenceable T_NULLSAFE_OBJECT_OPERATOR member_name
         | dereferenceable argument_list
         | class_ref T_DOUBLE_COLON T_VARIABLE
         | class_ref T_DOUBLE_COLON T_STRING argument_list
         ;

/* то, к чему можно применить [ ], -> и ( ): переменная, (выражение), foo(), new Foo() */
dereferenceable : variable
                | '(' expr ')'
                | function_call
                | new_expr
                ;

/* то, чему можно присвоить значение: $a, $a[0], $a[], $o->p */
lvalue : variable
       | dereferenceable '[' ']'
       ;

/* имя свойства или метода после -> и ?-> */
member_name : T_STRING
            | T_VARIABLE
            ;

/* слева от :: стоит имя класса или static (parent, self - обычные имена) */
class_ref : name
          | T_STATIC
          ;

/* Выражения */

expr : T_LNUMBER
     | T_DNUMBER
     | T_CONSTANT_STRING
     | T_MAGIC_CONST
     | T_TRUE
     | T_FALSE
     | T_NULL
     | double_quoted_string
     | dereferenceable
     | name
     | array_literal
     | assignment
     | incdec
     | unary
     | binary
     | conditional
     | match
     | T_PRINT expr %prec T_LOGICAL_AND
     | T_THROW expr
     | T_NEW class_ref
     | expr T_INSTANCEOF class_ref
     | class_ref T_DOUBLE_COLON T_STRING
     | class_ref T_DOUBLE_COLON T_CLASS
     | anonymous_function
     | arrow_function
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

/* Массивы: [1, 2], array(1, 2), ['a' => 1] */

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

/* Литералы: строки в двойных кавычках */

double_quoted_string : '"' encaps_list '"'
                     ;

encaps_list : %empty
            | encaps_list T_ENCAPSED_AND_WHITESPACE
            | encaps_list encaps_var
            ;

/* Подстановка значений в строки */
encaps_var : T_VARIABLE
           | T_VARIABLE '[' encaps_var_offset ']'
           | T_VARIABLE T_OBJECT_OPERATOR T_STRING
           | T_VARIABLE T_NULLSAFE_OBJECT_OPERATOR T_STRING
           | T_DOLLAR_OPEN_CURLY_BRACES expr '}'
           | T_DOLLAR_OPEN_CURLY_BRACES T_STRING_VARNAME '}'
           | T_DOLLAR_OPEN_CURLY_BRACES T_STRING_VARNAME '[' expr ']' '}'
           | T_CURLY_OPEN variable '}'
           ;

/* ключ в простой вставке "$a[key]", "$a[0]", "$a[-1]", "$a[$i]" */
encaps_var_offset : T_STRING
                  | T_LNUMBER
                  | '-' T_LNUMBER
                  | T_VARIABLE
                  ;

/* Консоль: echo, print, printf/fgets/readline */

echo_stmt : T_ECHO echo_list ';'
          ;

echo_list : expr
          | echo_list ',' expr
          ;

/* Развилки: if/elseif/else, switch, match, ?:, ?? */

if_stmt : if_without_else %prec T_NOELSE
        | if_without_else T_ELSE stmt
        | alt_if_without_else T_ENDIF ';'
        | alt_if_without_else T_ELSE ':' stmt_list T_ENDIF ';'
        ;

if_without_else : T_IF '(' expr ')' stmt
                | if_without_else T_ELSEIF '(' expr ')' stmt
                ;

/* альтернативный синтаксис: if (...): ... elseif (...): ... else: ... endif; */
alt_if_without_else : T_IF '(' expr ')' ':' stmt_list
                    | alt_if_without_else T_ELSEIF '(' expr ')' ':' stmt_list
                    ;

switch_stmt : T_SWITCH '(' expr ')' '{' case_list '}'
            | T_SWITCH '(' expr ')' '{' ';' case_list '}'
            | T_SWITCH '(' expr ')' ':' case_list T_ENDSWITCH ';'
            | T_SWITCH '(' expr ')' ':' ';' case_list T_ENDSWITCH ';'
            ;

case_list : %empty
          | case_list T_CASE expr case_separator stmt_list
          | case_list T_DEFAULT case_separator stmt_list
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

/* Циклы: while, do-while, for, foreach */

while_stmt : T_WHILE '(' expr ')' stmt
           | T_WHILE '(' expr ')' ':' stmt_list T_ENDWHILE ';'
           ;

do_while_stmt : T_DO stmt T_WHILE '(' expr ')' ';'
              ;

for_stmt : T_FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' stmt
         | T_FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' ':' stmt_list T_ENDFOR ';'
         ;

/* части заголовка for могут быть пустыми и содержать несколько выражений через запятую */
for_exprs : %empty
          | non_empty_for_exprs
          ;

non_empty_for_exprs : expr
                    | non_empty_for_exprs ',' expr
                    ;

foreach_stmt : T_FOREACH '(' expr T_AS foreach_variable ')' foreach_body
             | T_FOREACH '(' expr T_AS foreach_variable T_DOUBLE_ARROW foreach_variable ')' foreach_body
             ;

foreach_body : stmt
             | ':' stmt_list T_ENDFOREACH ';'
             ;

/* $v, &$v (по ссылке), [$a, $b] и list($a, $b) (разбор элемента на части) */
foreach_variable : variable
                 | '&' variable
                 | array_literal
                 | T_LIST '(' array_items_opt ')'
                 ;

/* ---- Функции: объявление, параметры, вызов (п. 11) ---- */

function_declaration : T_FUNCTION returns_ref T_STRING '(' parameter_list ')' return_type '{' stmt_list '}'    { }
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
parameter : promotion optional_type is_reference is_variadic T_VARIABLE
          | promotion optional_type is_reference is_variadic T_VARIABLE '=' expr
          ;

/* public/private/protected/readonly перед параметром конструктора объявляет свойство */
promotion : %empty
          | visibility
          | T_READONLY
          | visibility T_READONLY
          | T_READONLY visibility
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
            | ':' T_STATIC
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
         | T_STRING ':' expr
         | T_ELLIPSIS expr
         ;

/* Исключения: try / catch / finally, throw  */

/* throw - выражение, поэтому работает и как оператор, и внутри ?? и т. п. */
try_stmt : T_TRY block catch_list
         | T_TRY block catch_list finally_clause
         | T_TRY block finally_clause
         ;

catch_list : catch_clause
           | catch_list catch_clause
           ;

/* catch (A | B $e), catch (A) - переменная необязательна */
catch_clause : T_CATCH '(' catch_types optional_catch_var ')' block
             ;

catch_types : name
            | catch_types '|' name
            ;

optional_catch_var : %empty
                   | T_VARIABLE
                   ;

finally_clause : T_FINALLY block
               ;

/* Классы, интерфейсы, свойства, методы, наследование */

class_declaration : class_modifiers T_CLASS T_STRING extends_clause implements_clause '{' class_member_list '}'
                  | T_INTERFACE T_STRING interface_extends_clause '{' interface_member_list '}'
                  ;

class_modifiers : %empty
                | class_modifiers class_modifier
                ;

class_modifier : T_ABSTRACT
               | T_FINAL
               | T_READONLY
               ;

extends_clause : %empty
               | T_EXTENDS name
               ;

implements_clause : %empty
                  | T_IMPLEMENTS name_list
                  ;

/* interface A extends B, C */
interface_extends_clause : %empty
                         | T_EXTENDS name_list
                         ;

name_list : name
          | name_list ',' name
          ;

class_member_list : %empty
                  | class_member_list class_member
                  ;

class_member : property_declaration
             | class_constant_declaration
             | method_declaration
             ;

/* в интерфейсе нет свойств: только константы и методы */
interface_member_list : %empty
                      | interface_member_list interface_member
                      ;

interface_member : class_constant_declaration
                 | method_declaration
                 ;

/* public int $x = 0, $y;   var $z;   static $count; */
property_declaration : member_modifiers optional_type property_list ';'
                     | T_VAR optional_type property_list ';'
                     ;

property_list : property_item
              | property_list ',' property_item
              ;

property_item : T_VARIABLE
              | T_VARIABLE '=' expr
              ;

/* const A = 1, B = 2;   private const C = 3; */
class_constant_declaration : member_modifiers_opt T_CONST const_list ';'
                           ;

const_list : const_item
           | const_list ',' const_item
           ;

const_item : identifier '=' expr
           ;

/* тело ';' нужно абстрактным методам и методам интерфейсов */
method_declaration : member_modifiers_opt T_FUNCTION returns_ref identifier '(' parameter_list ')' return_type method_body
                   ;

method_body : ';'
            | block
            ;

/* Контроль доступа и другие модификаторы членов класса */

/* имя метода или константы класса: обычное слово или служебное (function private(), const list = 1) */
identifier : T_STRING
           | T_ECHO | T_ARRAY | T_TRUE | T_FALSE | T_NULL
           | T_ABSTRACT | T_AS | T_BREAK | T_CALLABLE | T_CASE | T_CATCH | T_CLASS | T_CLONE
           | T_CONST | T_CONTINUE | T_DECLARE | T_DEFAULT | T_DO | T_ELSE | T_ELSEIF | T_EMPTY
           | T_ENDDECLARE | T_ENDFOR | T_ENDFOREACH | T_ENDIF | T_ENDSWITCH | T_ENDWHILE
           | T_ENUM | T_EVAL | T_EXIT | T_EXTENDS | T_FINAL | T_FINALLY | T_FN | T_FOR | T_FOREACH
           | T_FUNCTION | T_GLOBAL | T_GOTO | T_IF | T_IMPLEMENTS | T_INCLUDE | T_INCLUDE_ONCE
           | T_INSTANCEOF | T_INSTEADOF | T_INTERFACE | T_ISSET | T_LIST | T_MATCH | T_NAMESPACE
           | T_NEW | T_PRINT | T_PRIVATE | T_PROTECTED | T_PUBLIC | T_READONLY | T_REQUIRE
           | T_REQUIRE_ONCE | T_RETURN | T_STATIC | T_SWITCH | T_THROW | T_TRAIT | T_TRY
           | T_UNSET | T_USE | T_VAR | T_WHILE | T_YIELD | T_YIELD_FROM
           | T_LOGICAL_AND | T_LOGICAL_OR | T_LOGICAL_XOR
           ;

member_modifiers_opt : %empty
                     | member_modifiers
                     ;

member_modifiers : plain_modifier_list
                 | visibility plain_modifiers
                 | plain_modifier_list visibility plain_modifiers
                 ;

plain_modifier_list : plain_modifier
                    | plain_modifier_list plain_modifier
                    ;

plain_modifiers : %empty
                | plain_modifiers plain_modifier
                ;

plain_modifier : T_STATIC
               | T_ABSTRACT
               | T_FINAL
               | T_READONLY
               ;

visibility : T_PUBLIC
           | T_PROTECTED
           | T_PRIVATE
           ;

/* Замыкания: function() use (...) {...}, fn() => ... */

anonymous_function : T_FUNCTION returns_ref '(' parameter_list ')' lexical_vars return_type block
                   | T_STATIC T_FUNCTION returns_ref '(' parameter_list ')' lexical_vars return_type block
                   ;

/* тело - одно выражение, а не блок */
arrow_function : T_FN returns_ref '(' parameter_list ')' return_type T_DOUBLE_ARROW expr %prec T_FN
               | T_STATIC T_FN returns_ref '(' parameter_list ')' return_type T_DOUBLE_ARROW expr %prec T_FN
               ;

/* use ($a, &$b) - захваченные переменные; пустой список use () недопустим */
lexical_vars : %empty
             | T_USE '(' lexical_var_list possible_comma ')'
             ;

lexical_var_list : lexical_var
                 | lexical_var_list ',' lexical_var
                 ;

lexical_var : T_VARIABLE
            | '&' T_VARIABLE
            ;

/* Создание объекта */

/* new Foo(1, 2);  new static;  (без скобок: new Foo) */
new_expr : T_NEW class_ref argument_list
         ;

/* Общие вспомогательные правила */

optional_expr : %empty
              | expr
              ;

possible_comma : %empty
               | ','
               ;

/* имя функции или константы: foo, Foo\bar, \foo, namespace\foo */
name : T_STRING
     | T_NAME_QUALIFIED
     | T_NAME_FULLY_QUALIFIED
     | T_NAME_RELATIVE
     ;

%%

void yyerror(const char* msg) {
    if (Console::HadErrors()) return;
    fprintf(stderr, "Syntax error at line %d: %s\n", yylineno, msg);
}