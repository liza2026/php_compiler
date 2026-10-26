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
%token <str>  T_ID T_NAME_QUALIFIED T_NAME_FULLY_QUALIFIED T_NAME_RELATIVE T_MAGIC_CONST
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


/* Приоритеты */
%precedence T_THROW T_FN
%left  T_LOGICAL_OR
%left  T_LOGICAL_XOR
%left  T_LOGICAL_AND
%right '=' T_PLUS_EQUAL T_MINUS_EQUAL T_MUL_EQUAL T_DIV_EQUAL T_CONCAT_EQUAL T_MOD_EQUAL
       T_POW_EQUAL T_AND_EQUAL T_OR_EQUAL T_XOR_EQUAL T_SL_EQUAL T_SR_EQUAL T_COALESCE_EQUAL
%nonassoc '?' ':'
%left  T_SHORT_TERNARY
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
     | T_BREAK expr_e ';'
     | T_CONTINUE expr_e ';'
     | T_RETURN expr_e ';'
     | function_declaration
     | try_stmt
     | class_declaration
     ;

block : '{' stmt_list '}'
      ;

/* Переменные и доступ к элементу массива */

/* $a, $$a, ${expr}, $a[0], $o->p, $o?->p, $o->m(), $f(1), Foo::$x, Foo::$$x, Foo::bar() */
variable : simple_variable
         | dereferenceable '[' expr_e ']'
         | dereferenceable T_OBJECT_OPERATOR member_name
         | dereferenceable T_NULLSAFE_OBJECT_OPERATOR member_name
         | dereferenceable argument_list
         | class_ref T_DOUBLE_COLON simple_variable
         | class_ref T_DOUBLE_COLON T_ID argument_list
         ;

/* переменная по имени: $a, переменная-переменная $$a, $$$a, ${expr} (имя - значение выражения) */
simple_variable : T_VARIABLE
                | '$' simple_variable
                | '$' '{' expr '}'
                ;

/* то, к чему можно применить [ ], -> и ( ): переменная, (выражение), foo(), new Foo() */
dereferenceable : variable
                | '(' expr ')'
                | name argument_list
                | T_NEW class_ref argument_list
                ;

/* имя свойства или метода после -> и ?->: $o->p, $o->$name, $o->{expr} */
member_name : T_ID
            | simple_variable
            | '{' expr '}'
            ;

/* слева от :: и после new стоит имя класса, static, переменная ($cls) или (выражение);
   parent, self - обычные имена */
class_ref : name
          | T_STATIC
          | simple_variable
          | '(' expr ')'
          ;

/* Выражения */

expr : T_LNUMBER
     | T_DNUMBER
     | T_CONSTANT_STRING
     | T_MAGIC_CONST
     | T_TRUE
     | T_FALSE
     | T_NULL
     | dereferenceable
     | name
     | array_literal
     | variable '='              expr       /* !$a = 5 == !($a = 5) */
     | variable T_PLUS_EQUAL     expr
     | variable T_MINUS_EQUAL    expr
     | variable T_MUL_EQUAL      expr
     | variable T_DIV_EQUAL      expr
     | variable T_CONCAT_EQUAL   expr
     | variable T_MOD_EQUAL      expr
     | variable T_POW_EQUAL      expr
     | variable T_AND_EQUAL      expr
     | variable T_OR_EQUAL       expr
     | variable T_XOR_EQUAL      expr
     | variable T_SL_EQUAL       expr
     | variable T_SR_EQUAL       expr
     | variable T_COALESCE_EQUAL expr
     | T_INC variable
     | T_DEC variable
     | variable T_INC
     | variable T_DEC
     | '-' expr %prec T_UNARY
     | '+' expr %prec T_UNARY
     | '~' expr %prec T_UNARY
     | '@' expr %prec T_UNARY
     | '!' expr
     | T_CLONE expr %prec T_UNARY
     | expr '+' expr
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
     | expr '?' expr ':' expr                  /* a ? b : c */
     | expr '?' ':' expr %prec T_SHORT_TERNARY /* a ?: b */
     | expr T_COALESCE expr                    /* a ?? b */
     | T_MATCH '(' expr ')' '{' match_arm_list_e '}'
     | T_PRINT expr %prec T_LOGICAL_AND
     | T_THROW expr
     | T_NEW class_ref
     | expr T_INSTANCEOF class_ref
     | class_ref T_DOUBLE_COLON T_ID
     | class_ref T_DOUBLE_COLON T_CLASS
     | T_FUNCTION is_reference '(' parameter_list_e ')' lexical_vars return_type block
     | T_STATIC T_FUNCTION is_reference '(' parameter_list_e ')' lexical_vars return_type block
     | T_FN is_reference '(' parameter_list_e ')' return_type T_DOUBLE_ARROW expr %prec T_FN
     | T_STATIC T_FN is_reference '(' parameter_list_e ')' return_type T_DOUBLE_ARROW expr %prec T_FN
     ;

/* выражения через запятую: echo, заголовок for, условия ветки match */
expr_list : expr
          | expr_list ',' expr
          ;

/* необязательное выражение */
expr_e : %empty
       | expr
       ;

/* Массивы: [1, 2], array(1, 2), ['a' => 1], [new A(), new B()] */

/* массив */
array_literal : '[' array_items_opt ']'
              | T_ARRAY '(' array_items_opt ')'
              | T_LIST  '(' array_items_opt ')'
              ;

/* список элементов массива */
array_items_opt : %empty
                | array_items
                | array_items ','
                ;

array_items : expr
            | expr T_DOUBLE_ARROW expr
            | array_items ',' expr
            | array_items ',' expr T_DOUBLE_ARROW expr
            ;

/* Консоль: echo, print, printf/fgets/readline */

/* оператор echo */
echo_stmt : T_ECHO expr_list ';'
          ;

/* Развилки: if/elseif/else, switch, match */

/* оператор if */
if_stmt : if_without_else %prec T_NOELSE
        | if_without_else T_ELSE stmt
        | alt_if_without_else T_ENDIF ';'
        | alt_if_without_else T_ELSE ':' stmt_list T_ENDIF ';'
        ;

/* if без else */
if_without_else : T_IF '(' expr ')' stmt
                | if_without_else T_ELSEIF '(' expr ')' stmt
                ;

/* альтернативный синтаксис: if (...): ... elseif (...): ... else: ... endif; */
alt_if_without_else : T_IF '(' expr ')' ':' stmt_list
                    | alt_if_without_else T_ELSEIF '(' expr ')' ':' stmt_list
                    ;

/* оператор switch; перед первым case допустимо любое число ';' */
switch_stmt : T_SWITCH '(' expr ')' '{' semicolons_e case_list '}'
            | T_SWITCH '(' expr ')' ':' semicolons_e case_list T_ENDSWITCH ';'
            ;

/* ';' подряд (после последнего case они разбираются как пустые операторы его stmt_list) */
semicolons_e : %empty
             | semicolons_e ';'
             ;

/* ветки switch */
case_list : %empty
          | case_list T_CASE expr ':' stmt_list
          | case_list T_CASE expr ';' stmt_list
          | case_list T_DEFAULT ':' stmt_list
          | case_list T_DEFAULT ';' stmt_list
          ;

/* ветки match */
match_arm_list_e : %empty
                 | match_arm_list possible_comma
                 ;

/* хотя бы одна ветка match */
match_arm_list : expr_list possible_comma T_DOUBLE_ARROW expr
               | T_DEFAULT possible_comma T_DOUBLE_ARROW expr
               | match_arm_list ',' expr_list possible_comma T_DOUBLE_ARROW expr
               | match_arm_list ',' T_DEFAULT possible_comma T_DOUBLE_ARROW expr
               ;

/* Циклы: while, do-while, for, foreach */

/* цикл while */
while_stmt : T_WHILE '(' expr ')' stmt
           | T_WHILE '(' expr ')' ':' stmt_list T_ENDWHILE ';'
           ;

/* цикл do-while */
do_while_stmt : T_DO stmt T_WHILE '(' expr ')' ';'
              ;

/* цикл for: части заголовка могут быть пустыми и содержать несколько выражений через запятую */
for_stmt : T_FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' stmt
         | T_FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' ':' stmt_list T_ENDFOR ';'
         ;

for_exprs : %empty
          | expr_list
          ;

/* цикл foreach: $array as $value; $array as $key => $value */
foreach_stmt : T_FOREACH '(' expr T_AS foreach_variable ')' stmt
             | T_FOREACH '(' expr T_AS foreach_variable ')' ':' stmt_list T_ENDFOREACH ';'
             | T_FOREACH '(' expr T_AS foreach_variable T_DOUBLE_ARROW foreach_variable ')' stmt
             | T_FOREACH '(' expr T_AS foreach_variable T_DOUBLE_ARROW foreach_variable ')' ':' stmt_list T_ENDFOREACH ';'
             ;

/* $v, &$v (по ссылке), [$a, $b] и list($a, $b) (разбор элемента на части) */
foreach_variable : variable
                 | '&' variable
                 | array_literal
                 ;

/* Функции: объявление, параметры, вызов */

/* объявление функции */
function_declaration : T_FUNCTION is_reference T_ID '(' parameter_list_e ')' return_type block
                     ;

/* список параметров: [модификаторы] [тип] [&] [...]$имя [= значение] */
parameter_list_e : %empty
                | parameter_list possible_comma
                ;


parameter_list : parameter
               | parameter_list ',' parameter
               ;

/* [модификаторы] [тип] [&] $имя = значение по умолчанию */
/* [модификаторы] [тип] [&] ...$имя */
parameter : modifiers_e type_e is_reference T_VARIABLE
          | modifiers_e type_e is_reference T_VARIABLE '=' expr
          | modifiers_e type_e is_reference T_ELLIPSIS T_VARIABLE
          ;

/* необязательный &: параметр по ссылке, function &f(), use (&$x) */
is_reference : %empty
             | '&'
             ;

/* необязательный тип */
type_e : %empty
       | type
       ;

/* необязательный тип возврата */
return_type : %empty
            | ':' type
            | ':' T_STATIC
            ;

/* Типы: int, ?string, int|float */

/* тип: int, ?int, int|string|null */
type : type_name
     | '?' type_name
     | type '|' type_name
     ;

/* одно имя типа; null, false, true - отдельные ключевые слова: int|false, string|null */
type_name : T_ARRAY
          | T_CALLABLE
          | T_NULL
          | T_FALSE
          | T_TRUE
          | name
          ;

/* аргументы в скобках */
argument_list : '(' ')'
              | '(' non_empty_argument_list possible_comma ')'
              | '(' T_ELLIPSIS ')'
              ;

/* хотя бы один аргумент */
non_empty_argument_list : argument
                        | non_empty_argument_list ',' argument
                        ;

/* позиционный, именованный (width: 10) и распаковка (...$args) */
argument : expr
         | T_ID ':' expr
         | T_ELLIPSIS expr
         ;

/* Исключения: try / catch / finally, throw  */

/* try нужен хотя бы один catch или finally (это проверяется позже, как ошибка компиляции) */
try_stmt : T_TRY block catch_list_e finally_e
         ;

catch_list_e : %empty
             | catch_list_e catch_clause
             ;

/* catch (A | B $e), catch (A) - переменная необязательна */
catch_clause : T_CATCH '(' catch_types catch_var_e ')' block
             ;

/* типы исключений в catch */
catch_types : name
            | catch_types '|' name
            ;

/* необязательная переменная в catch */
catch_var_e : %empty
            | T_VARIABLE
            ;

/* необязательный блок finally */
finally_e : %empty
          | T_FINALLY block
          ;

/* Классы и интерфейсы: свойства, константы, методы, наследование */

/* объявление класса или интерфейса */
class_declaration : modifiers_e T_CLASS T_ID class_heritage '{' class_member_list '}'
                  | T_INTERFACE T_ID class_heritage '{' class_member_list '}'
                  ;

/* extends и implements */
class_heritage : %empty
               | class_heritage T_EXTENDS name_list
               | class_heritage T_IMPLEMENTS name_list
               ;

/* имена через запятую */
name_list : name
          | name_list ',' name
          ;

/* члены класса и интерфейса (свойства в интерфейсе - ошибка компиляции) */
class_member_list : %empty
                  | class_member_list class_member
                  ;

/* член класса */
class_member : member_modifiers type_e property_list ';'
             | T_VAR type_e property_list ';'
             | modifiers_e T_CONST const_list ';'
             | modifiers_e T_FUNCTION is_reference identifier '(' parameter_list_e ')' return_type block
             | modifiers_e T_FUNCTION is_reference identifier '(' parameter_list_e ')' return_type ';'
             ;

/* свойства через запятую */
property_list : T_VARIABLE
              | T_VARIABLE '=' expr
              | property_list ',' T_VARIABLE
              | property_list ',' T_VARIABLE '=' expr
              ;

/* константы через запятую */
const_list : identifier '=' expr
           | const_list ',' identifier '=' expr
           ;

/* имя метода или константы класса: обычное слово или служебное (function private(), const list = 1) */
identifier : T_ID
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

/* Модификаторы классов, членов класса и параметров-свойств конструктора */

modifiers_e : %empty
            | member_modifiers
            ;

member_modifiers : member_modifier
                 | member_modifiers member_modifier
                 ;

member_modifier : T_PUBLIC
                | T_PROTECTED
                | T_PRIVATE
                | T_STATIC
                | T_ABSTRACT
                | T_FINAL
                | T_READONLY
                ;

/* Замыкания: use ($a, &$b) - захваченные переменные; пустой список use () недопустим */

lexical_vars : %empty
             | T_USE '(' lexical_var_list possible_comma ')'
             ;

/* захваченные переменные */
lexical_var_list : is_reference T_VARIABLE
                 | lexical_var_list ',' is_reference T_VARIABLE
                 ;


/* Общие вспомогательные правила */

/* необязательная запятая в конце списка */
possible_comma : %empty
               | ','
               ;

/* имя функции или константы: foo, Foo\bar, \foo, namespace\foo */
name : T_ID
     | T_NAME_QUALIFIED
     | T_NAME_FULLY_QUALIFIED
     | T_NAME_RELATIVE
     ;

%%


void yyerror(const char* msg) {
    if (Console::HadErrors()) return;
    fprintf(stderr, "Syntax error at line %d: %s\n", yylineno, msg);
}