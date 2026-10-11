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

%%

void yyerror(const char* msg) {
    fprintf(stderr, "Syntax error at line %d: %s\n", yylineno, msg);
}