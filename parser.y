%define parse.error verbose
%define parse.trace

%code requires {
    #include <string>
}

%{
#include <cstdio>
#include <string>
#include "core/helpers/Console.h"

extern int lastToken;
int parserErrors = 0;

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
%token <str>  VARIABLE INLINE_HTML CONSTANT_STRING
%token <str>  ID NAME_QUALIFIED NAME_FULLY_QUALIFIED NAME_RELATIVE MAGIC_CONST
%token <ival> LNUMBER
%token <dval> DNUMBER
%token ERROR

/* Ключевые слова и константы */
%token ECHO ARRAY TRUE FALSE NULLPTR
%token ABSTRACT AS BREAK CALLABLE CASE CATCH CLASS CLONE CONST CONTINUE
%token DECLARE DEFAULT DO ELSE ELSEIF EMPTY
%token ENDDECLARE ENDFOR ENDFOREACH ENDIF ENDSWITCH ENDWHILE
%token ENUM EVAL EXIT EXTENDS FINAL FINALLY FN FOR FOREACH FUNCTION
%token GLOBAL GOTO IF IMPLEMENTS INCLUDE INCLUDE_ONCE INSTANCEOF INSTEADOF
%token INTERFACE ISSET LIST MATCH NAMESPACE NEW PRINT
%token PRIVATE PROTECTED PUBLIC READONLY REQUIRE REQUIRE_ONCE RETURN
%token STATIC SWITCH THROW TRAIT TRY UNSET USE VAR WHILE YIELD YIELD_FROM
%token PARENT SELF

/* Приведения типов, обращение к члену класса, атрибуты */
%token INT_CAST DOUBLE_CAST STRING_CAST ARRAY_CAST OBJECT_CAST BOOL_CAST
%token OBJECT_OPERATOR NULLSAFE_OBJECT_OPERATOR DOUBLE_COLON ATTRIBUTE

/* Операторы из нескольких символов */
%token ELLIPSIS DOUBLE_ARROW
%token INC DEC POW
%token SPACESHIP COALESCE
%token IS_EQUAL IS_NOT_EQUAL IS_IDENTICAL IS_NOT_IDENTICAL
%token IS_SMALLER_OR_EQUAL IS_GREATER_OR_EQUAL
%token BOOLEAN_AND BOOLEAN_OR
%token LOGICAL_AND LOGICAL_OR LOGICAL_XOR
%token SL SR
%token PLUS_EQUAL MINUS_EQUAL MUL_EQUAL DIV_EQUAL CONCAT_EQUAL MOD_EQUAL
%token POW_EQUAL AND_EQUAL OR_EQUAL XOR_EQUAL SL_EQUAL SR_EQUAL COALESCE_EQUAL


/* Приоритеты */
%precedence THROW FN
%left  LOGICAL_OR
%left  LOGICAL_XOR
%left  LOGICAL_AND
%right '=' PLUS_EQUAL MINUS_EQUAL MUL_EQUAL DIV_EQUAL CONCAT_EQUAL MOD_EQUAL
       POW_EQUAL AND_EQUAL OR_EQUAL XOR_EQUAL SL_EQUAL SR_EQUAL COALESCE_EQUAL
%nonassoc '?' ':'
%left  SHORT_TERNARY
%right COALESCE
%left  BOOLEAN_OR
%left  BOOLEAN_AND
%left  '|'
%left  '^'
%left  '&'
%nonassoc IS_EQUAL IS_NOT_EQUAL IS_IDENTICAL IS_NOT_IDENTICAL SPACESHIP
%nonassoc '<' IS_SMALLER_OR_EQUAL '>' IS_GREATER_OR_EQUAL
%left  '.'
%left  SL SR
%left  '+' '-'
%left  '*' '/' '%'
%right '!'
%nonassoc INSTANCEOF
%precedence UNARY
%right POW


%%

/* Программа и операторы */

program : stmt_list
        ;

stmt_list : %empty
          | stmt_list stmt
          ;

stmt : ';'
     | expr ';'
     | INLINE_HTML
     | block
     | BREAK expr_e ';'
     | CONTINUE expr_e ';'
     | RETURN expr_e ';'
     | ECHO expr_list ';'
     | WHILE '(' expr ')' stmt
     | WHILE '(' expr ')' ':' stmt_list ENDWHILE ';'
     | DO stmt WHILE '(' expr ')' ';'
     | FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' stmt
     | FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' ':' stmt_list ENDFOR ';'
     | FOREACH '(' expr AS foreach_variable ')' stmt
     | FOREACH '(' expr AS foreach_variable ')' ':' stmt_list ENDFOREACH ';'
     | FOREACH '(' expr AS foreach_variable DOUBLE_ARROW foreach_variable ')' stmt
     | FOREACH '(' expr AS foreach_variable DOUBLE_ARROW foreach_variable ')' ':' stmt_list ENDFOREACH ';'
     | IF '(' expr ')' stmt else_if_stmts
     | IF '(' expr ')' stmt else_if_stmts ELSE stmt
     | IF '(' expr ')' ':' stmt_list alt_else_if_stmts ENDIF ';'
     | IF '(' expr ')' ':' stmt_list alt_else_if_stmts ELSE ':' stmt_list ENDIF ';'
     | SWITCH '(' expr ')' '{' case_list '}'
     | SWITCH '(' expr ')' '{' ';' case_list '}'
     | SWITCH '(' expr ')' ':' case_list ENDSWITCH ';'
     | SWITCH '(' expr ')' ':' ';' case_list ENDSWITCH ';'
     | TRY block catch_list_e
     | TRY block catch_list_e FINALLY block
     | FUNCTION is_reference ID '(' parameter_list_e ')' return_type block
     | modifiers_e CLASS ID class_heritage '{' class_member_list '}'
     | INTERFACE ID class_heritage '{' class_member_list '}'
     | error ';'
     ;

block : '{' stmt_list '}'
      ;

/* $a, $$a, ${expr}, $a[0], $o->p, $o?->p, $o->m(), $f(1), Foo::$x, Foo::$$x, Foo::bar() */
variable : simple_variable
         | dereferenceable '[' expr_e ']'
         | dereferenceable OBJECT_OPERATOR ID
         | dereferenceable OBJECT_OPERATOR simple_variable
         | dereferenceable OBJECT_OPERATOR '{' expr '}'
         | dereferenceable NULLSAFE_OBJECT_OPERATOR ID
         | dereferenceable NULLSAFE_OBJECT_OPERATOR simple_variable
         | dereferenceable NULLSAFE_OBJECT_OPERATOR '{' expr '}'
         | dereferenceable argument_list_e /* f(1), $o->m()->n[0]() */
         | class_ref DOUBLE_COLON simple_variable
         | class_ref DOUBLE_COLON ID argument_list_e
         ;

simple_variable : VARIABLE
                | '$' simple_variable /* $$a, $$$a */
                | '$' '{' expr '}'    /* ${'a'.'b'} */
                ;

/* то, к чему можно применить [ ], -> и ( ): переменная, (выражение), foo(), new Foo() */
dereferenceable : variable
                | '(' expr ')'              /* (new A)->b: скобки как основа цепочки */
                | name argument_list_e      /* f(1) */
                | NEW class_ref argument_list_e
                ;

/* слева от :: и после new стоит имя класса, static, parent, self, переменная ($cls) или (выражение);  */
class_ref : name
          | STATIC
          | SELF
          | PARENT
          | simple_variable
          | '(' expr ')'
          ;

expr : LNUMBER
     | DNUMBER
     | CONSTANT_STRING
     | MAGIC_CONST
     | TRUE
     | FALSE
     | NULLPTR
     | dereferenceable
     | name
     | '[' array_items_opt ']'
     | ARRAY '(' array_items_opt ')'
     | LIST  '(' array_items_opt ')'
     | variable '='              expr       /* !$a = 5 == !($a = 5) */
     | variable PLUS_EQUAL     expr
     | variable MINUS_EQUAL    expr
     | variable MUL_EQUAL      expr
     | variable DIV_EQUAL      expr
     | variable CONCAT_EQUAL   expr
     | variable MOD_EQUAL      expr
     | variable POW_EQUAL      expr
     | variable AND_EQUAL      expr
     | variable OR_EQUAL       expr
     | variable XOR_EQUAL      expr
     | variable SL_EQUAL       expr
     | variable SR_EQUAL       expr
     | variable COALESCE_EQUAL expr
     | INC variable
     | DEC variable
     | variable INC
     | variable DEC
     | '-' expr %prec UNARY
     | '+' expr %prec UNARY
     | '~' expr %prec UNARY
     | '@' expr %prec UNARY
     | '!' expr
     | CLONE expr %prec UNARY
     | expr '+' expr
     | expr '-' expr
     | expr '*' expr
     | expr '/' expr
     | expr '%' expr
     | expr POW expr
     | expr '.' expr
     | expr SL expr
     | expr SR expr
     | expr '&' expr
     | expr '|' expr
     | expr '^' expr
     | expr '<' expr
     | expr '>' expr
     | expr IS_SMALLER_OR_EQUAL expr
     | expr IS_GREATER_OR_EQUAL expr
     | expr IS_EQUAL expr
     | expr IS_NOT_EQUAL expr
     | expr IS_IDENTICAL expr
     | expr IS_NOT_IDENTICAL expr
     | expr SPACESHIP expr
     | expr BOOLEAN_AND expr
     | expr BOOLEAN_OR expr
     | expr LOGICAL_AND expr
     | expr LOGICAL_OR expr
     | expr LOGICAL_XOR expr
     | expr '?' expr ':' expr                  /* a ? b : c */
     | expr '?' ':' expr %prec SHORT_TERNARY   /* a ?: b: нужен свой уровень, иначе конфликт с полным ?: */
     | expr COALESCE expr
     | MATCH '(' expr ')' '{' '}'
     | MATCH '(' expr ')' '{' match_arm_list possible_comma '}'
     | PRINT expr %prec LOGICAL_AND /* print 1 and 2 == (print 1) and 2 */
     | THROW expr
     | NEW class_ref
     | expr INSTANCEOF class_ref
     | class_ref DOUBLE_COLON ID
     | class_ref DOUBLE_COLON CLASS
     | FUNCTION is_reference '(' parameter_list_e ')' return_type block
     | FUNCTION is_reference '(' parameter_list_e ')' USE '(' lexical_var_list possible_comma ')' return_type block
     | STATIC FUNCTION is_reference '(' parameter_list_e ')' return_type block
     | STATIC FUNCTION is_reference '(' parameter_list_e ')' USE '(' lexical_var_list possible_comma ')' return_type block
     | FN is_reference '(' parameter_list_e ')' return_type DOUBLE_ARROW expr %prec FN /* тело fn забирает всё до конца */
     | STATIC FN is_reference '(' parameter_list_e ')' return_type DOUBLE_ARROW expr %prec FN
     ;

/* выражения через запятую: echo, заголовок for, условия ветки match */
expr_list : expr
          | expr_list ',' expr
          ;

/* необязательное выражение */
expr_e : %empty
       | expr
       ;

/* список элементов массива */
array_items_opt : %empty
                | array_items
                | array_items ',' /* висячая запятая */
                ;

array_items : expr
            | expr DOUBLE_ARROW expr
            | array_items ',' expr
            | array_items ',' expr DOUBLE_ARROW expr
            ;

/* цепочка elseif: elseif (...) stmt */
else_if_stmts : %empty
              | else_if_stmts ELSEIF '(' expr ')' stmt
              ;

/* альтернативный синтаксис: elseif (...): stmt_list */
alt_else_if_stmts : %empty
                  | alt_else_if_stmts ELSEIF '(' expr ')' ':' stmt_list
                  ;

/* ветки switch */
case_list : %empty
          | case_list CASE expr ':' stmt_list
          | case_list CASE expr ';' stmt_list
          | case_list DEFAULT ':' stmt_list
          | case_list DEFAULT ';' stmt_list
          ;

/* хотя бы одна ветка match */
match_arm_list : expr_list possible_comma DOUBLE_ARROW expr
               | DEFAULT possible_comma DOUBLE_ARROW expr
               | match_arm_list ',' expr_list possible_comma DOUBLE_ARROW expr
               | match_arm_list ',' DEFAULT possible_comma DOUBLE_ARROW expr
               ;

for_exprs : %empty
          | expr_list
          ;

/* $v, &$v (по ссылке), [$a, $b] и list($a, $b) (разбор элемента на части) */
foreach_variable : variable
                 | '&' variable
                 |  '[' array_items_opt ']'
                 | ARRAY '(' array_items_opt ')'
                 | LIST  '(' array_items_opt ')'
                 ;

/* список параметров: [модификаторы] [тип] [&] [...]$имя [= значение] */
parameter_list_e : %empty
                | parameter_list possible_comma
                ;

parameter_list : parameter
               | parameter_list ',' parameter
               ;

/* [модификаторы] [тип] [&] $имя = значение по умолчанию
   [модификаторы] [тип] [&] ...$имя */
parameter : modifiers_e type_e is_reference VARIABLE
          | modifiers_e type_e is_reference VARIABLE '=' expr
          | modifiers_e type_e is_reference ELLIPSIS VARIABLE
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
            | ':' STATIC /* static как возвращаемый тип: function create(): static */
            ;

/* тип: int, ?int, int|string|null */
type : type_name
     | '?' type_name
     | type '|' type_name
     ;

/* одно имя типа; null, false, true - отдельные ключевые слова: int|false, string|null */
type_name : ARRAY
          | CALLABLE
          | NULLPTR
          | FALSE
          | TRUE
          | SELF
          | PARENT
          | name
          ;

/* аргументы в скобках */
argument_list_e : '(' ')'
                | '(' argument_list possible_comma ')'
                | '(' ELLIPSIS ')' /* не пустой аргумент, а callable: $g = strlen(...); */
                ;

/* хотя бы один аргумент */
argument_list : expr
              | ID ':' expr
              | ELLIPSIS expr
              | argument_list ',' expr
              | argument_list ',' ID ':' expr
              | argument_list ',' ELLIPSIS expr
              ;

/* catch (A | B $e), catch (A) - переменная необязательна */
catch_list_e : %empty
             | catch_list_e CATCH '(' catch_types ')' block            /* catch (A) {}: переменная необязательна */
             | catch_list_e CATCH '(' catch_types VARIABLE ')' block /* catch ($e) без типа — ошибка */
             ;

/* типы исключений в catch */
catch_types : name
            | catch_types '|' name
            ;

/* extends и implements */
class_heritage : %empty
               | class_heritage EXTENDS name_list
               | class_heritage IMPLEMENTS name_list
               ;

/* имена через запятую */
name_list : name
          | name_list ',' name
          ;

/* члены класса и интерфейса */
class_member_list : %empty
                  | class_member_list member_modifiers type_e property_list ';' /* свойство требует модификатор */
                  | class_member_list VAR type_e property_list ';'
                  | class_member_list modifiers_e CONST const_list ';'
                  | class_member_list modifiers_e FUNCTION is_reference identifier '(' parameter_list_e ')' return_type block
                  | class_member_list modifiers_e FUNCTION is_reference identifier '(' parameter_list_e ')' return_type ';' /* abstract / интерфейс */
                  ;

/* свойства через запятую */
property_list : VARIABLE
              | VARIABLE '=' expr
              | property_list ',' VARIABLE
              | property_list ',' VARIABLE '=' expr
              ;

/* константы через запятую */
const_list : identifier '=' expr
           | const_list ',' identifier '=' expr
           ;

/* имя метода или константы класса: обычное слово или служебное (function private(), const list = 1) */
identifier : ID
           | ECHO | ARRAY | TRUE | FALSE | NULLPTR
           | ABSTRACT | AS | BREAK | CALLABLE | CASE | CATCH | CLASS | CLONE
           | CONST | CONTINUE | DECLARE | DEFAULT | DO | ELSE | ELSEIF | EMPTY
           | ENDDECLARE | ENDFOR | ENDFOREACH | ENDIF | ENDSWITCH | ENDWHILE
           | ENUM | EVAL | EXIT | EXTENDS | FINAL | FINALLY | FN | FOR | FOREACH
           | FUNCTION | GLOBAL | GOTO | IF | IMPLEMENTS | INCLUDE | INCLUDE_ONCE
           | INSTANCEOF | INSTEADOF | INTERFACE | ISSET | LIST | MATCH | NAMESPACE
           | NEW | PRINT | PRIVATE | PROTECTED | PUBLIC | READONLY | REQUIRE
           | REQUIRE_ONCE | RETURN | STATIC | SWITCH | THROW | TRAIT | TRY
           | UNSET | USE | VAR | WHILE | YIELD | YIELD_FROM
           | LOGICAL_AND | LOGICAL_OR | LOGICAL_XOR
           ;

modifiers_e : %empty
            | member_modifiers
            ;

member_modifiers : member_modifier
                 | member_modifiers member_modifier
                 ;

member_modifier : PUBLIC
                | PROTECTED
                | PRIVATE
                | STATIC
                | ABSTRACT
                | FINAL
                | READONLY
                ;

/* захваченные переменные use ($a, &$b) */
lexical_var_list : is_reference VARIABLE
                 | lexical_var_list ',' is_reference VARIABLE
                 ;

/* необязательная запятая в конце списка */
possible_comma : %empty
               | ','
               ;

/* имя функции или константы: foo, Foo\bar, \foo, namespace\foo */
name : ID
     | NAME_QUALIFIED
     | NAME_FULLY_QUALIFIED
     | NAME_RELATIVE
     ;

%%


void yyerror(const char* msg) {
    if (lastToken == ERROR) return;   /* лексер уже сообщил об этой ошибке */
    parserErrors++;
    fprintf(stderr, "Syntax error at line %d: %s\n", yylineno, msg);
}