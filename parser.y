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
%token <str>  ID MAGIC_CONST
%token <ival> LNUMBER
%token <dval> DNUMBER
%token ERROR

/* Ключевые слова и константы */
%token ECHO ARRAY TRUE FALSE NULLPTR
%token ABSTRACT AS BREAK CALLABLE CASE CATCH CLASS CLONE CONST CONTINUE
%token DECLARE DEFAULT DO ELSE ELSEIF EMPTY
%token ENDDECLARE ENDFOR ENDFOREACH ENDIF ENDSWITCH ENDWHILE
%token EVAL EXIT EXTENDS FINAL FINALLY FN FOR FOREACH FUNCTION
%token GLOBAL GOTO IF IMPLEMENTS INCLUDE INCLUDE_ONCE INSTANCEOF INSTEADOF
%token INTERFACE ISSET LIST MATCH NEW PRINT
%token PRIVATE PROTECTED PUBLIC READONLY REQUIRE REQUIRE_ONCE RETURN
%token STATIC SWITCH THROW TRAIT TRY UNSET USE VAR WHILE YIELD YIELD_FROM
%token PARENT SELF

/* Обращение к члену класса */
%token OBJECT_OPERATOR NULLSAFE_OBJECT_OPERATOR DOUBLE_COLON

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
%nonassoc INC DEC
%left  '[' '(' OBJECT_OPERATOR NULLSAFE_OBJECT_OPERATOR DOUBLE_COLON /* ->, ::, [ ], ( ) - самые тесные операции */
%precedence NEW

%%

/* Программа и операторы */

program : %empty
        | program top_stmt
        ;

/* Верхний уровень - единственное место, где можно объявлять функции и классы.
   Внутри блоков и тел if/while/for/... разрешён только stmt */
top_stmt : stmt
         | FUNCTION is_reference ID '(' parameter_list_e ')' return_type block
         | modifiers_e CLASS ID '{' class_member_list '}'
         | modifiers_e CLASS ID EXTENDS ID '{' class_member_list '}'
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
     | FOREACH '(' expr AS variable ')' stmt
     | FOREACH '(' expr AS '&' variable ')' stmt
     | FOREACH '(' expr AS '[' foreach_array_items ']' ')' stmt
     | FOREACH '(' expr AS variable DOUBLE_ARROW is_reference variable ')' stmt
     | FOREACH '(' expr AS variable ')' ':' stmt_list ENDFOREACH ';'
     | FOREACH '(' expr AS '&' variable ')' ':' stmt_list ENDFOREACH ';'
     | FOREACH '(' expr AS '[' foreach_array_items ']' ')' ':' stmt_list ENDFOREACH ';'
     | FOREACH '(' expr AS variable DOUBLE_ARROW is_reference variable ')' ':' stmt_list ENDFOREACH ';'
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
     | error ';'
     ;

block : '{' stmt_list '}'
      ;

/* $a, $$a, $$$a, ${'a'.'b'} */
variable : VARIABLE
         | '$' variable
         | '$' '{' expr '}'
         ;

expr : LNUMBER
     | DNUMBER
     | CONSTANT_STRING
     | MAGIC_CONST
     | TRUE
     | FALSE
     | NULLPTR
     | ID
     | SELF
     | PARENT
     | STATIC
     | variable
     | '(' expr ')'
     | '[' array_items_opt ']'
     | ARRAY '(' array_items_opt ')'
     | expr '[' expr_e ']'
     | expr OBJECT_OPERATOR ID
     | expr OBJECT_OPERATOR variable
     | expr OBJECT_OPERATOR '{' expr '}'
     | expr NULLSAFE_OBJECT_OPERATOR ID
     | expr NULLSAFE_OBJECT_OPERATOR variable
     | expr NULLSAFE_OBJECT_OPERATOR '{' expr '}'
     | expr DOUBLE_COLON ID
     | expr DOUBLE_COLON variable
     | expr '(' ')'
     | expr '(' argument_list possible_comma ')'
     | expr '(' ELLIPSIS ')' /* не пустой аргумент, а callable: $g = strlen(...); */
     | '&' expr %prec UNARY /* ссылка: = &$a, foreach (... as &$v), [&$a, $b] */
     | expr '='              expr
     | expr PLUS_EQUAL     expr
     | expr MINUS_EQUAL    expr
     | expr MUL_EQUAL      expr
     | expr DIV_EQUAL      expr
     | expr CONCAT_EQUAL   expr
     | expr MOD_EQUAL      expr
     | expr POW_EQUAL      expr
     | expr AND_EQUAL      expr
     | expr OR_EQUAL       expr
     | expr XOR_EQUAL      expr
     | expr SL_EQUAL       expr
     | expr SR_EQUAL       expr
     | expr COALESCE_EQUAL expr
     | INC expr
     | DEC expr
     | expr INC
     | expr DEC
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
     | PRINT expr %prec LOGICAL_AND /* print 1 and 2 == (print 1) and 2 */
     | THROW expr
     | NEW expr
     | expr INSTANCEOF expr
     | FUNCTION is_reference '(' parameter_list_e ')' return_type block
     | FUNCTION is_reference '(' parameter_list_e ')' USE '(' lexical_var_list possible_comma ')' return_type block
     | STATIC FUNCTION is_reference '(' parameter_list_e ')' return_type block
     | STATIC FUNCTION is_reference '(' parameter_list_e ')' USE '(' lexical_var_list possible_comma ')' return_type block
     | FN is_reference '(' parameter_list_e ')' return_type DOUBLE_ARROW expr %prec FN /* тело fn забирает всё до конца */
     | STATIC FN is_reference '(' parameter_list_e ')' return_type DOUBLE_ARROW expr %prec FN
     ;

/* выражения через запятую: echo, заголовок for */
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

for_exprs : %empty
          | expr_list
          ;

/* $v, &$v, [$a, $b], [&$a, $b] */
/* Элементы списка переменных foreach */
foreach_array_items : %empty
		    | is_reference variable
                    | foreach_array_items ',' is_reference variable
                    | foreach_array_items ','
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
          | ID
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
catch_types : ID
            | catch_types '|' ID
            ;

/* члены класса */
class_member_list : %empty
                  | class_member_list member_modifiers type_e property_list ';' /* свойство требует модификатор */
                  | class_member_list VAR type_e property_list ';'
                  | class_member_list modifiers_e CONST const_list ';'
                  | class_member_list modifiers_e FUNCTION is_reference identifier '(' parameter_list_e ')' return_type block
                  | class_member_list modifiers_e FUNCTION is_reference identifier '(' parameter_list_e ')' return_type ';'
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
           | EVAL | EXIT | EXTENDS | FINAL | FINALLY | FN | FOR | FOREACH
           | FUNCTION | GLOBAL | GOTO | IF | IMPLEMENTS | INCLUDE | INCLUDE_ONCE
           | INSTANCEOF | INSTEADOF | INTERFACE | ISSET | LIST | MATCH
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

%%

void yyerror(const char* msg) {
    if (lastToken == ERROR) return;   /* лексер уже сообщил об этой ошибке */
    parserErrors++;
    fprintf(stderr, "Syntax error at line %d: %s\n", yylineno, msg);
}