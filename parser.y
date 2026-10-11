%define parse.error verbose
%define parse.trace

%code requires {
    #include <string>
}

%{
#include <cstdio>

int yylex();
extern int yylineno;
void yyerror(const char* msg);
%}

%union {
    long long    ival;
    double       dval;
    std::string* str;
}

%token <str>  T_VARIABLE T_INLINE_HTML
%token <ival> T_LNUMBER
%token <dval> T_DNUMBER
%token T_ECHO

%right '='
%left '+' '-'
%left '*' '/' '%'
%precedence T_UMINUS

%start program

%%

program
    : statement_list
    ;

statement_list
    : %empty
    | statement_list statement
    ;

statement
    : ';'
    | expr ';'
    | T_ECHO expr ';'
    | T_INLINE_HTML    { }
    ;

variable
    : T_VARIABLE       { }
    ;

expr
    : T_LNUMBER        { }
    | T_DNUMBER        { }
    | variable
    | variable '=' expr
    | expr '+' expr
    | expr '-' expr
    | expr '*' expr
    | expr '/' expr
    | expr '%' expr
    | '-' expr %prec T_UMINUS
    | '(' expr ')'
    ;

%%

void yyerror(const char* msg) {
    fprintf(stderr, "Syntax error at line %d: %s\n", yylineno, msg);
}