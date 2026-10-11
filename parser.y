%define parse.error verbose

%{
#include <cstdio>

int yylex();
extern int yylineno;
void yyerror(const char* msg);
%}

%start program

%%

program
    : %empty
    ;

%%

void yyerror(const char* msg) {
    fprintf(stderr, "Syntax error at line %d: %s\n", yylineno, msg);
}