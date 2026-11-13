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
%token <str>  INLINE_HTML CONSTANT_STRING
%token <str>  ID
%token <ival> LNUMBER
%token <dval> DNUMBER
%token ERROR

/* Ключевые слова и константы */
%token ECHO_KW ARRAY TRUE FALSE NULLPTR
%token AS BREAK CASE CATCH CLASS CONST CONTINUE
%token DEFAULT DO ELSE ELSEIF
%token ENDFOR ENDFOREACH ENDIF ENDSWITCH ENDWHILE
%token EXTENDS FINALLY FN FOR FOREACH FUNCTION
%token IF INSTANCEOF
%token NEW
%token PRIVATE PROTECTED PUBLIC RETURN
%token STATIC SWITCH THROW TRY USE VAR WHILE
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
%token POW_EQUAL AND_EQUAL XOR_EQUAL SL_EQUAL SR_EQUAL COALESCE_EQUAL


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
%left  '[' '(' OBJECT_OPERATOR NULLSAFE_OBJECT_OPERATOR DOUBLE_COLON
%precedence NEW

%%

/* Программа и операторы */

program
    : %empty { Console::ParserLog("program (empty)"); }
    | program top_stmt { Console::ParserLog("program (program top_stmt)"); }
    ;

/* Верхний уровень */
top_stmt
    : stmt { Console::ParserLog("top_stmt (stmt)"); }
    | FUNCTION is_reference ID '(' parameter_list_e ')' return_type block { Console::ParserLog("top_stmt (FUNCTION is_reference ID parameter_list_e return_type block)"); }
    | modifiers_e CLASS ID '{' class_member_list '}' { Console::ParserLog("top_stmt (modifiers_e CLASS ID class_member_list)"); }
    | modifiers_e CLASS ID EXTENDS ID '{' class_member_list '}' { Console::ParserLog("top_stmt (modifiers_e CLASS ID EXTENDS ID class_member_list)"); }
    ;

stmt_list
    : %empty { Console::ParserLog("stmt_list (empty)"); }
    | stmt_list stmt { Console::ParserLog("stmt_list (stmt_list stmt)"); }
    ;

stmt
    : ';' { Console::ParserLog("stmt (;)"); }
    | expr ';' { Console::ParserLog("stmt (expr ;)"); }
    | INLINE_HTML { Console::ParserLog("stmt (INLINE_HTML)"); }
    | block { Console::ParserLog("stmt (block)"); }
    | BREAK expr_e ';' { Console::ParserLog("stmt (BREAK expr_e ;)"); }
    | CONTINUE expr_e ';' { Console::ParserLog("stmt (CONTINUE expr_e ;)"); }
    | RETURN expr_e ';' { Console::ParserLog("stmt (RETURN expr_e ;)"); }
    | ECHO_KW expr_list ';' { Console::ParserLog("stmt (ECHO_KW expr_list ;)"); }
    | WHILE '(' expr ')' stmt { Console::ParserLog("stmt (WHILE expr stmt)"); }
    | WHILE '(' expr ')' ':' stmt_list ENDWHILE ';' { Console::ParserLog("stmt (WHILE expr stmt_list ENDWHILE)"); }
    | DO stmt WHILE '(' expr ')' ';' { Console::ParserLog("stmt (DO stmt WHILE expr)"); }
    | FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' stmt { Console::ParserLog("stmt (FOR for_exprs for_exprs for_exprs stmt)"); }
    | FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' ':' stmt_list ENDFOR ';' { Console::ParserLog("stmt (FOR for_exprs for_exprs for_exprs stmt_list ENDFOR)"); }
    | FOREACH '(' expr AS '$' ID ')' stmt { Console::ParserLog("stmt (FOREACH expr AS $ ID stmt)"); }
    | FOREACH '(' expr AS '&' '$' ID ')' stmt { Console::ParserLog("stmt (FOREACH expr AS & $ ID stmt)"); }
    | FOREACH '(' expr AS '[' foreach_array_items ']' ')' stmt { Console::ParserLog("stmt (FOREACH expr AS foreach_array_items stmt)"); }
    | FOREACH '(' expr AS '$' ID DOUBLE_ARROW is_reference '$' ID ')' stmt { Console::ParserLog("stmt (FOREACH expr AS $ ID DOUBLE_ARROW is_reference $ ID stmt)"); }
    | FOREACH '(' expr AS '$' ID ')' ':' stmt_list ENDFOREACH ';' { Console::ParserLog("stmt (FOREACH expr AS $ ID stmt_list ENDFOREACH)"); }
    | FOREACH '(' expr AS '&' '$' ID ')' ':' stmt_list ENDFOREACH ';' { Console::ParserLog("stmt (FOREACH expr AS & $ ID stmt_list ENDFOREACH)"); }
    | FOREACH '(' expr AS '[' foreach_array_items ']' ')' ':' stmt_list ENDFOREACH ';' { Console::ParserLog("stmt (FOREACH expr AS foreach_array_items stmt_list ENDFOREACH)"); }
    | FOREACH '(' expr AS '$' ID DOUBLE_ARROW is_reference '$' ID ')' ':' stmt_list ENDFOREACH ';' { Console::ParserLog("stmt (FOREACH expr AS $ ID DOUBLE_ARROW is_reference $ ID stmt_list ENDFOREACH)"); }
    | IF '(' expr ')' stmt else_if_stmts { Console::ParserLog("stmt (IF expr stmt else_if_stmts)"); }
    | IF '(' expr ')' stmt else_if_stmts ELSE stmt { Console::ParserLog("stmt (IF expr stmt else_if_stmts ELSE stmt)"); }
    | IF '(' expr ')' ':' stmt_list alt_else_if_stmts ENDIF ';' { Console::ParserLog("stmt (IF expr stmt_list alt_else_if_stmts ENDIF)"); }
    | IF '(' expr ')' ':' stmt_list alt_else_if_stmts ELSE ':' stmt_list ENDIF ';' { Console::ParserLog("stmt (IF expr stmt_list alt_else_if_stmts ELSE stmt_list ENDIF)"); }
    | SWITCH '(' expr ')' '{' case_list '}' { Console::ParserLog("stmt (SWITCH expr case_list)"); }
    | SWITCH '(' expr ')' '{' ';' case_list '}' { Console::ParserLog("stmt (SWITCH ; case_list)"); }
    | SWITCH '(' expr ')' ':' case_list ENDSWITCH ';' { Console::ParserLog("stmt (SWITCH expr case_list ENDSWITCH)"); }
    | SWITCH '(' expr ')' ':' ';' case_list ENDSWITCH ';' { Console::ParserLog("stmt (SWITCH ; case_list ENDSWITCH)"); }
    | TRY block catch_list_e { Console::ParserLog("stmt (TRY block catch_list_e)"); }
    | TRY block catch_list_e FINALLY block { Console::ParserLog("stmt (TRY block catch_list_e FINALLY block)"); }
    | error ';' { Console::ParserLog("stmt (error ;)"); }
    ;

block
    : '{' stmt_list '}' { Console::ParserLog("block ({ stmt_list })"); }
    ;

/* $a, $$a, $$$a, ${'a'.'b'} */
variable
    : '$' ID { Console::ParserLog("variable ($ ID)"); }
    | '$' variable { Console::ParserLog("variable ($ variable)"); }
    | '$' '{' expr '}' { Console::ParserLog("variable (${ expr })"); }
    ;

expr
    : LNUMBER { Console::ParserLog("expr (LNUMBER)"); }
    | DNUMBER { Console::ParserLog("expr (DNUMBER)"); }
    | CONSTANT_STRING { Console::ParserLog("expr (CONSTANT_STRING)"); }
    | TRUE { Console::ParserLog("expr (TRUE)"); }
    | FALSE { Console::ParserLog("expr (FALSE)"); }
    | NULLPTR { Console::ParserLog("expr (NULLPTR)"); }
    | ID { Console::ParserLog("expr (ID)"); }
    | SELF { Console::ParserLog("expr (SELF)"); }
    | PARENT { Console::ParserLog("expr (PARENT)"); }
    | STATIC { Console::ParserLog("expr (STATIC)"); }
    | variable { Console::ParserLog("expr (variable)"); }
    | '(' expr ')' { Console::ParserLog("expr (( expr ))"); }
    | '[' array_items_opt ']' { Console::ParserLog("expr ([ array_items_opt ])"); }
    | ARRAY '(' array_items_opt ')' { Console::ParserLog("expr (ARRAY array_items_opt)"); }
    | expr '[' expr_e ']' { Console::ParserLog("expr (expr [ expr_e ])"); }
    | expr OBJECT_OPERATOR ID { Console::ParserLog("expr (expr OBJECT_OPERATOR ID)"); }
    | expr OBJECT_OPERATOR variable { Console::ParserLog("expr (expr OBJECT_OPERATOR variable)"); }
    | expr OBJECT_OPERATOR '{' expr '}' { Console::ParserLog("expr (expr OBJECT_OPERATOR { expr })"); }
    | expr NULLSAFE_OBJECT_OPERATOR ID { Console::ParserLog("expr (expr NULLSAFE_OBJECT_OPERATOR ID)"); }
    | expr NULLSAFE_OBJECT_OPERATOR variable { Console::ParserLog("expr (expr NULLSAFE_OBJECT_OPERATOR variable)"); }
    | expr NULLSAFE_OBJECT_OPERATOR '{' expr '}' { Console::ParserLog("expr (expr NULLSAFE_OBJECT_OPERATOR { expr })"); }
    | expr DOUBLE_COLON ID { Console::ParserLog("expr (expr DOUBLE_COLON ID)"); }
    | expr DOUBLE_COLON variable { Console::ParserLog("expr (expr DOUBLE_COLON variable)"); }
    | expr '(' ')' { Console::ParserLog("expr (expr ())"); }
    | expr '(' argument_list possible_comma ')' { Console::ParserLog("expr (expr argument_list possible_comma)"); }
    | '&' expr %prec UNARY { Console::ParserLog("expr (& expr)"); }
    | expr '=' expr { Console::ParserLog("expr (expr = expr)"); }
    | expr PLUS_EQUAL expr { Console::ParserLog("expr (expr PLUS_EQUAL expr)"); }
    | expr MINUS_EQUAL expr { Console::ParserLog("expr (expr MINUS_EQUAL expr)"); }
    | expr MUL_EQUAL expr { Console::ParserLog("expr (expr MUL_EQUAL expr)"); }
    | expr DIV_EQUAL expr { Console::ParserLog("expr (expr DIV_EQUAL expr)"); }
    | expr CONCAT_EQUAL expr { Console::ParserLog("expr (expr CONCAT_EQUAL expr)"); }
    | expr MOD_EQUAL expr { Console::ParserLog("expr (expr MOD_EQUAL expr)"); }
    | expr POW_EQUAL expr { Console::ParserLog("expr (expr POW_EQUAL expr)"); }
    | expr AND_EQUAL expr { Console::ParserLog("expr (expr AND_EQUAL expr)"); }
    | expr OR_EQUAL expr { Console::ParserLog("expr (expr OR_EQUAL expr)"); }
    | expr XOR_EQUAL expr { Console::ParserLog("expr (expr XOR_EQUAL expr)"); }
    | expr SL_EQUAL expr { Console::ParserLog("expr (expr SL_EQUAL expr)"); }
    | expr SR_EQUAL expr { Console::ParserLog("expr (expr SR_EQUAL expr)"); }
    | expr COALESCE_EQUAL expr { Console::ParserLog("expr (expr COALESCE_EQUAL expr)"); }
    | INC expr { Console::ParserLog("expr (INC expr)"); }
    | DEC expr { Console::ParserLog("expr (DEC expr)"); }
    | expr INC { Console::ParserLog("expr (expr INC)"); }
    | expr DEC { Console::ParserLog("expr (expr DEC)"); }
    | '-' expr %prec UNARY { Console::ParserLog("expr (- expr)"); }
    | '+' expr %prec UNARY { Console::ParserLog("expr (+ expr)"); }
    | '~' expr %prec UNARY { Console::ParserLog("expr (~ expr)"); }
    | '@' expr %prec UNARY { Console::ParserLog("expr (@ expr)"); }
    | '!' expr { Console::ParserLog("expr (! expr)"); }
    | expr '+' expr { Console::ParserLog("expr (expr + expr)"); }
    | expr '-' expr { Console::ParserLog("expr (expr - expr)"); }
    | expr '*' expr { Console::ParserLog("expr (expr * expr)"); }
    | expr '/' expr { Console::ParserLog("expr (expr / expr)"); }
    | expr '%' expr { Console::ParserLog("expr (expr % expr)"); }
    | expr POW expr { Console::ParserLog("expr (expr POW expr)"); }
    | expr '.' expr { Console::ParserLog("expr (expr . expr)"); }
    | expr SL expr { Console::ParserLog("expr (expr SL expr)"); }
    | expr SR expr { Console::ParserLog("expr (expr SR expr)"); }
    | expr '&' expr { Console::ParserLog("expr (expr & expr)"); }
    | expr '|' expr { Console::ParserLog("expr (expr | expr)"); }
    | expr '^' expr { Console::ParserLog("expr (expr ^ expr)"); }
    | expr '<' expr { Console::ParserLog("expr (expr < expr)"); }
    | expr '>' expr { Console::ParserLog("expr (expr > expr)"); }
    | expr IS_SMALLER_OR_EQUAL expr { Console::ParserLog("expr (expr IS_SMALLER_OR_EQUAL expr)"); }
    | expr IS_GREATER_OR_EQUAL expr { Console::ParserLog("expr (expr IS_GREATER_OR_EQUAL expr)"); }
    | expr IS_EQUAL expr { Console::ParserLog("expr (expr IS_EQUAL expr)"); }
    | expr IS_NOT_EQUAL expr { Console::ParserLog("expr (expr IS_NOT_EQUAL expr)"); }
    | expr IS_IDENTICAL expr { Console::ParserLog("expr (expr IS_IDENTICAL expr)"); }
    | expr IS_NOT_IDENTICAL expr { Console::ParserLog("expr (expr IS_NOT_IDENTICAL expr)"); }
    | expr SPACESHIP expr { Console::ParserLog("expr (expr SPACESHIP expr)"); }
    | expr BOOLEAN_AND expr { Console::ParserLog("expr (expr BOOLEAN_AND expr)"); }
    | expr BOOLEAN_OR expr { Console::ParserLog("expr (expr BOOLEAN_OR expr)"); }
    | expr LOGICAL_AND expr { Console::ParserLog("expr (expr LOGICAL_AND expr)"); }
    | expr LOGICAL_OR expr { Console::ParserLog("expr (expr LOGICAL_OR expr)"); }
    | expr LOGICAL_XOR expr { Console::ParserLog("expr (expr LOGICAL_XOR expr)"); }
    | expr '?' expr ':' expr { Console::ParserLog("expr (expr ? expr : expr)"); }
    | expr '?' ':' expr %prec SHORT_TERNARY { Console::ParserLog("expr (expr ? : expr)"); }
    | expr COALESCE expr { Console::ParserLog("expr (expr COALESCE expr)"); }
    | THROW expr { Console::ParserLog("expr (THROW expr)"); }
    | NEW expr { Console::ParserLog("expr (NEW expr)"); }
    | expr INSTANCEOF expr { Console::ParserLog("expr (expr INSTANCEOF expr)"); }
    | FUNCTION is_reference '(' parameter_list_e ')' return_type block { Console::ParserLog("expr (FUNCTION is_reference parameter_list_e return_type block)"); }
    | FUNCTION is_reference '(' parameter_list_e ')' USE '(' lexical_var_list possible_comma ')' return_type block { Console::ParserLog("expr (FUNCTION is_reference parameter_list_e USE lexical_var_list return_type block)"); }
    | STATIC FUNCTION is_reference '(' parameter_list_e ')' return_type block { Console::ParserLog("expr (STATIC FUNCTION is_reference parameter_list_e return_type block)"); }
    | STATIC FUNCTION is_reference '(' parameter_list_e ')' USE '(' lexical_var_list possible_comma ')' return_type block { Console::ParserLog("expr (STATIC FUNCTION is_reference parameter_list_e USE lexical_var_list return_type block)"); }
    | FN is_reference '(' parameter_list_e ')' return_type DOUBLE_ARROW expr %prec FN { Console::ParserLog("expr (FN is_reference parameter_list_e return_type DOUBLE_ARROW expr)"); }
    | STATIC FN is_reference '(' parameter_list_e ')' return_type DOUBLE_ARROW expr %prec FN { Console::ParserLog("expr (STATIC FN is_reference parameter_list_e return_type DOUBLE_ARROW expr)"); }
    ;

/* выражения через запятую: echo, заголовок for */
expr_list
    : expr { Console::ParserLog("expr_list (expr)"); }
    | expr_list ',' expr { Console::ParserLog("expr_list (expr_list , expr)"); }
    ;

/* необязательное выражение */
expr_e
    : %empty { Console::ParserLog("expr_e (empty)"); }
    | expr { Console::ParserLog("expr_e (expr)"); }
    ;

/* список элементов массива */
array_items_opt
    : %empty { Console::ParserLog("array_items_opt (empty)"); }
    | array_items { Console::ParserLog("array_items_opt (array_items)"); }
    | array_items ',' { Console::ParserLog("array_items_opt (array_items ,)"); }
    ;

array_items
    : expr { Console::ParserLog("array_items (expr)"); }
    | expr DOUBLE_ARROW expr { Console::ParserLog("array_items (expr DOUBLE_ARROW expr)"); }
    | ELLIPSIS expr { Console::ParserLog("array_items (ELLIPSIS expr)"); }
    | array_items ',' expr { Console::ParserLog("array_items (array_items , expr)"); }
    | array_items ',' expr DOUBLE_ARROW expr { Console::ParserLog("array_items (array_items , expr DOUBLE_ARROW expr)"); }
    | array_items ',' ELLIPSIS expr { Console::ParserLog("array_items (array_items , ELLIPSIS expr)"); }
    ;

/* цепочка elseif */
else_if_stmts
    : %empty { Console::ParserLog("else_if_stmts (empty)"); }
    | else_if_stmts ELSEIF '(' expr ')' stmt { Console::ParserLog("else_if_stmts (else_if_stmts ELSEIF expr stmt)"); }
    ;

/* альтернативный синтаксис elseif */
alt_else_if_stmts
    : %empty { Console::ParserLog("alt_else_if_stmts (empty)"); }
    | alt_else_if_stmts ELSEIF '(' expr ')' ':' stmt_list { Console::ParserLog("alt_else_if_stmts (alt_else_if_stmts ELSEIF expr stmt_list)"); }
    ;

/* ветки switch */
case_list
    : %empty { Console::ParserLog("case_list (empty)"); }
    | case_list CASE expr ':' stmt_list { Console::ParserLog("case_list (case_list CASE expr stmt_list)"); }
    | case_list CASE expr ';' stmt_list { Console::ParserLog("case_list (case_list CASE expr ; stmt_list)"); }
    | case_list DEFAULT ':' stmt_list { Console::ParserLog("case_list (case_list DEFAULT stmt_list)"); }
    | case_list DEFAULT ';' stmt_list { Console::ParserLog("case_list (case_list DEFAULT ; stmt_list)"); }
    ;

for_exprs
    : %empty { Console::ParserLog("for_exprs (empty)"); }
    | expr_list { Console::ParserLog("for_exprs (expr_list)"); }
    ;

/* Элементы списка переменных foreach */
foreach_array_items
    : %empty { Console::ParserLog("foreach_array_items (empty)"); }
    | is_reference '$' ID { Console::ParserLog("foreach_array_items (is_reference $ ID)"); }
    | foreach_array_items ',' is_reference '$' ID { Console::ParserLog("foreach_array_items (foreach_array_items , is_reference $ ID)"); }
    | foreach_array_items ',' { Console::ParserLog("foreach_array_items (foreach_array_items ,)"); }
    ;

/* список параметров */
parameter_list_e
    : %empty { Console::ParserLog("parameter_list_e (empty)"); }
    | parameter_list possible_comma { Console::ParserLog("parameter_list_e (parameter_list possible_comma)"); }
    ;

parameter_list
    : parameter { Console::ParserLog("parameter_list (parameter)"); }
    | parameter_list ',' parameter { Console::ParserLog("parameter_list (parameter_list , parameter)"); }
    ;

/* параметры */
parameter
    : modifiers_e type_e is_reference '$' ID { Console::ParserLog("parameter (modifiers_e type_e is_reference $ ID)"); }
    | modifiers_e type_e is_reference '$' ID '=' expr { Console::ParserLog("parameter (modifiers_e type_e is_reference $ ID = expr)"); }
    | modifiers_e type_e is_reference ELLIPSIS '$' ID { Console::ParserLog("parameter (modifiers_e type_e is_reference ELLIPSIS $ ID)"); }
    ;

/* необязательный &: параметр по ссылке */
is_reference
    : %empty { Console::ParserLog("is_reference (empty)"); }
    | '&' { Console::ParserLog("is_reference (&)"); }
    ;

/* необязательный тип */
type_e
    : %empty { Console::ParserLog("type_e (empty)"); }
    | type { Console::ParserLog("type_e (type)"); }
    ;

/* необязательный тип возврата */
return_type
    : %empty { Console::ParserLog("return_type (empty)"); }
    | ':' type { Console::ParserLog("return_type (: type)"); }
    | ':' STATIC { Console::ParserLog("return_type (: STATIC)"); }
    ;

/* тип */
type
    : type_name { Console::ParserLog("type (type_name)"); }
    | '?' type_name { Console::ParserLog("type (? type_name)"); }
    | type '|' type_name { Console::ParserLog("type (type | type_name)"); }
    ;

/* одно имя типа */
type_name
    : ARRAY { Console::ParserLog("type_name (ARRAY)"); }
    | NULLPTR { Console::ParserLog("type_name (NULLPTR)"); }
    | FALSE { Console::ParserLog("type_name (FALSE)"); }
    | TRUE { Console::ParserLog("type_name (TRUE)"); }
    | SELF { Console::ParserLog("type_name (SELF)"); }
    | PARENT { Console::ParserLog("type_name (PARENT)"); }
    | ID { Console::ParserLog("type_name (ID)"); }
    ;

/* аргументы */
argument_list
    : expr { Console::ParserLog("argument_list (expr)"); }
    | ID ':' expr { Console::ParserLog("argument_list (ID : expr)"); }
    | ELLIPSIS expr { Console::ParserLog("argument_list (ELLIPSIS expr)"); }
    | argument_list ',' expr { Console::ParserLog("argument_list (argument_list , expr)"); }
    | argument_list ',' ID ':' expr { Console::ParserLog("argument_list (argument_list , ID : expr)"); }
    | argument_list ',' ELLIPSIS expr { Console::ParserLog("argument_list (argument_list , ELLIPSIS expr)"); }
    ;

/* catch */
catch_list_e
    : %empty { Console::ParserLog("catch_list_e (empty)"); }
    | catch_list_e CATCH '(' catch_types ')' block { Console::ParserLog("catch_list_e (catch_list_e CATCH catch_types block)"); }
    | catch_list_e CATCH '(' catch_types '$' ID ')' block { Console::ParserLog("catch_list_e (catch_list_e CATCH catch_types $ ID block)"); }
    ;

/* типы исключений в catch */
catch_types
    : ID { Console::ParserLog("catch_types (ID)"); }
    | catch_types '|' ID { Console::ParserLog("catch_types (catch_types | ID)"); }
    ;

/* члены класса */
class_member_list
    : %empty { Console::ParserLog("class_member_list (empty)"); }
    | class_member_list member_modifiers type_e property_list ';' { Console::ParserLog("class_member_list (class_member_list member_modifiers type_e property_list ;)"); }
    | class_member_list VAR type_e property_list ';' { Console::ParserLog("class_member_list (class_member_list VAR type_e property_list ;)"); }
    | class_member_list modifiers_e CONST const_list ';' { Console::ParserLog("class_member_list (class_member_list modifiers_e CONST const_list ;)"); }
    | class_member_list modifiers_e FUNCTION is_reference identifier '(' parameter_list_e ')' return_type block { Console::ParserLog("class_member_list (class_member_list modifiers_e FUNCTION is_reference identifier parameter_list_e return_type block)"); }
    | class_member_list modifiers_e FUNCTION is_reference identifier '(' parameter_list_e ')' return_type ';' { Console::ParserLog("class_member_list (class_member_list modifiers_e FUNCTION is_reference identifier parameter_list_e return_type ;)"); }
    ;

/* свойства через запятую */
property_list
    : '$' ID { Console::ParserLog("property_list ($ ID)"); }
    | '$' ID '=' expr { Console::ParserLog("property_list ($ ID = expr)"); }
    | property_list ',' '$' ID { Console::ParserLog("property_list (property_list , $ ID)"); }
    | property_list ',' '$' ID '=' expr { Console::ParserLog("property_list (property_list , $ ID = expr)"); }
    ;

/* константы через запятую */
const_list
    : identifier '=' expr { Console::ParserLog("const_list (identifier = expr)"); }
    | const_list ',' identifier '=' expr { Console::ParserLog("const_list (const_list , identifier = expr)"); }
    ;

/* имя метода или константы класса */
identifier
    : ID { Console::ParserLog("identifier (ID)"); }
    | ECHO_KW { Console::ParserLog("identifier (ECHO_KW)"); }
    | ARRAY { Console::ParserLog("identifier (ARRAY)"); }
    | TRUE { Console::ParserLog("identifier (TRUE)"); }
    | FALSE { Console::ParserLog("identifier (FALSE)"); }
    | NULLPTR { Console::ParserLog("identifier (NULLPTR)"); }
    | AS { Console::ParserLog("identifier (AS)"); }
    | BREAK { Console::ParserLog("identifier (BREAK)"); }
    | CASE { Console::ParserLog("identifier (CASE)"); }
    | CATCH { Console::ParserLog("identifier (CATCH)"); }
    | CLASS { Console::ParserLog("identifier (CLASS)"); }
    | CONST { Console::ParserLog("identifier (CONST)"); }
    | CONTINUE { Console::ParserLog("identifier (CONTINUE)"); }
    | DEFAULT { Console::ParserLog("identifier (DEFAULT)"); }
    | DO { Console::ParserLog("identifier (DO)"); }
    | ELSE { Console::ParserLog("identifier (ELSE)"); }
    | ELSEIF { Console::ParserLog("identifier (ELSEIF)"); }
    | ENDFOR { Console::ParserLog("identifier (ENDFOR)"); }
    | ENDFOREACH { Console::ParserLog("identifier (ENDFOREACH)"); }
    | ENDIF { Console::ParserLog("identifier (ENDIF)"); }
    | ENDSWITCH { Console::ParserLog("identifier (ENDSWITCH)"); }
    | ENDWHILE { Console::ParserLog("identifier (ENDWHILE)"); }
    | EXTENDS { Console::ParserLog("identifier (EXTENDS)"); }
    | FINALLY { Console::ParserLog("identifier (FINALLY)"); }
    | FN { Console::ParserLog("identifier (FN)"); }
    | FOR { Console::ParserLog("identifier (FOR)"); }
    | FOREACH { Console::ParserLog("identifier (FOREACH)"); }
    | FUNCTION { Console::ParserLog("identifier (FUNCTION)"); }
    | IF { Console::ParserLog("identifier (IF)"); }
    | INSTANCEOF { Console::ParserLog("identifier (INSTANCEOF)"); }
    | NEW { Console::ParserLog("identifier (NEW)"); }
    | PRIVATE { Console::ParserLog("identifier (PRIVATE)"); }
    | PROTECTED { Console::ParserLog("identifier (PROTECTED)"); }
    | PUBLIC { Console::ParserLog("identifier (PUBLIC)"); }
    | RETURN { Console::ParserLog("identifier (RETURN)"); }
    | STATIC { Console::ParserLog("identifier (STATIC)"); }
    | SWITCH { Console::ParserLog("identifier (SWITCH)"); }
    | THROW { Console::ParserLog("identifier (THROW)"); }
    | TRY { Console::ParserLog("identifier (TRY)"); }
    | USE { Console::ParserLog("identifier (USE)"); }
    | VAR { Console::ParserLog("identifier (VAR)"); }
    | WHILE { Console::ParserLog("identifier (WHILE)"); }
    | LOGICAL_AND { Console::ParserLog("identifier (LOGICAL_AND)"); }
    | LOGICAL_OR { Console::ParserLog("identifier (LOGICAL_OR)"); }
    | LOGICAL_XOR { Console::ParserLog("identifier (LOGICAL_XOR)"); }
    ;

modifiers_e
    : %empty { Console::ParserLog("modifiers_e (empty)"); }
    | member_modifiers { Console::ParserLog("modifiers_e (member_modifiers)"); }
    ;

member_modifiers
    : member_modifier { Console::ParserLog("member_modifiers (member_modifier)"); }
    | member_modifiers member_modifier { Console::ParserLog("member_modifiers (member_modifiers member_modifier)"); }
    ;

member_modifier
    : PUBLIC { Console::ParserLog("member_modifier (PUBLIC)"); }
    | PROTECTED { Console::ParserLog("member_modifier (PROTECTED)"); }
    | PRIVATE { Console::ParserLog("member_modifier (PRIVATE)"); }
    | STATIC { Console::ParserLog("member_modifier (STATIC)"); }
    ;

/* захваченные переменные use ($a, &$b) */
lexical_var_list
    : is_reference '$' ID { Console::ParserLog("lexical_var_list (is_reference $ ID)"); }
    | lexical_var_list ',' is_reference '$' ID { Console::ParserLog("lexical_var_list (lexical_var_list , is_reference $ ID)"); }
    ;

/* необязательная запятая в конце списка */
possible_comma
    : %empty { Console::ParserLog("possible_comma (empty)"); }
    | ',' { Console::ParserLog("possible_comma (, )"); }
    ;

%%

void yyerror(const char* msg) {
    if (lastToken == ERROR) return;   /* лексер уже сообщил об этой ошибке */
    parserErrors++;
    Console::ParserError(yylineno, msg);
}