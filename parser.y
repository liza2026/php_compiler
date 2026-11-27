%define parse.error verbose
%define parse.trace

%code requires {
    #include <string>
    #include <vector>
    #include "core/nodes/DeclNode.h"
}

%{
#include <cstdio>
#include <string>
#include <vector>
#include "core/helpers/Console.h"
#include "core/nodes/DeclNode.h"

extern int lastToken;
int parserErrors = 0;

/* корень синтаксического дерева - список операторов верхнего уровня */
std::vector<StmtNode*>* root = nullptr;

int yylex();
extern int yylineno;
void yyerror(const char* msg);
%}

%union {
    long long    ival;
    double       dval;
    std::string* str;
    bool         flag;
    int          mods;

    ExprNode*                       expr;
    std::vector<ExprNode*>*         exprList;
    StmtNode*                       stmt;
    std::vector<StmtNode*>*         stmtList;
    TypeNode*                       type;
    ParamNode*                      param;
    std::vector<ParamNode*>*        paramList;
    std::vector<std::string>*       strList;
    std::vector<ClassMemberNode*>*  memberList;
    std::vector<VarDeclNode*>*      varList;
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


/* Нетерминалы */
%type <stmtList>    program stmt_list else_if_stmts alt_else_if_stmts case_list catch_list_e
%type <stmt>        top_stmt stmt block
%type <expr>        expr expr_e variable
%type <exprList>    expr_list array_items_opt array_items for_exprs foreach_array_items argument_list
%type <paramList>   parameter_list_e parameter_list
%type <param>       parameter
%type <flag>        is_reference
%type <type>        type_e type return_type
%type <str>         type_name identifier
%type <strList>     catch_types
%type <memberList>  class_member_list
%type <varList>     property_list const_list
%type <mods>        modifiers_e member_modifiers member_modifier

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
    : %empty {
          Console::ParserLog("program (empty)");
          $$ = createList<StmtNode*>();
          root = $$;
      }
    | program top_stmt {
          Console::ParserLog("program (program top_stmt)");
          $$ = addToList($1, $2);
          root = $$;
      }
    ;

/* Верхний уровень */
top_stmt
    : stmt {
          Console::ParserLog("top_stmt (stmt)");
          $$ = $1;
      }
    | FUNCTION is_reference ID '(' parameter_list_e ')' return_type block {
          Console::ParserLog("top_stmt (FUNCTION is_reference ID parameter_list_e return_type block)");
          $$ = StmtNode::createFunctionDecl(FunctionNode::create($2, $3, $5, $7, $8));
      }
    | modifiers_e CLASS ID '{' class_member_list '}' {
          Console::ParserLog("top_stmt (modifiers_e CLASS ID class_member_list)");
          $$ = StmtNode::createClassDecl(ClassNode::create($1, $3, nullptr, $5));
      }
    | modifiers_e CLASS ID EXTENDS ID '{' class_member_list '}' {
          Console::ParserLog("top_stmt (modifiers_e CLASS ID EXTENDS ID class_member_list)");
          $$ = StmtNode::createClassDecl(ClassNode::create($1, $3, $5, $7));
      }
    ;

stmt_list
    : %empty {
          Console::ParserLog("stmt_list (empty)");
          $$ = createList<StmtNode*>();
      }
    | stmt_list stmt {
          Console::ParserLog("stmt_list (stmt_list stmt)");
          $$ = addToList($1, $2);
      }
    ;

stmt
    : ';' {
          Console::ParserLog("stmt (;)");
          $$ = StmtNode::createEmpty();
      }
    | expr ';' {
          Console::ParserLog("stmt (expr ;)");
          $$ = StmtNode::createExprStmt($1);
      }
    | INLINE_HTML {
          Console::ParserLog("stmt (INLINE_HTML)");
          $$ = StmtNode::createInlineHtml($1);
      }
    | block {
          Console::ParserLog("stmt (block)");
          $$ = $1;
      }
    | BREAK expr_e ';' {
          Console::ParserLog("stmt (BREAK expr_e ;)");
          $$ = StmtNode::createJump(BreakStmt, $2);
      }
    | CONTINUE expr_e ';' {
          Console::ParserLog("stmt (CONTINUE expr_e ;)");
          $$ = StmtNode::createJump(ContinueStmt, $2);
      }
    | RETURN expr_e ';' {
          Console::ParserLog("stmt (RETURN expr_e ;)");
          $$ = StmtNode::createJump(ReturnStmt, $2);
      }
    | ECHO_KW expr_list ';' {
          Console::ParserLog("stmt (ECHO_KW expr_list ;)");
          $$ = StmtNode::createEcho($2);
      }
    | WHILE '(' expr ')' stmt {
          Console::ParserLog("stmt (WHILE expr stmt)");
          $$ = StmtNode::createWhile($3, $5);
      }
    | WHILE '(' expr ')' ':' stmt_list ENDWHILE ';' {
          Console::ParserLog("stmt (WHILE expr stmt_list ENDWHILE)");
          $$ = StmtNode::createWhile($3, StmtNode::createBlock($6));
      }
    | DO stmt WHILE '(' expr ')' ';' {
          Console::ParserLog("stmt (DO stmt WHILE expr)");
          $$ = StmtNode::createDoWhile($2, $5);
      }
    | FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' stmt {
          Console::ParserLog("stmt (FOR for_exprs for_exprs for_exprs stmt)");
          $$ = StmtNode::createFor($3, $5, $7, $9);
      }
    | FOR '(' for_exprs ';' for_exprs ';' for_exprs ')' ':' stmt_list ENDFOR ';' {
          Console::ParserLog("stmt (FOR for_exprs for_exprs for_exprs stmt_list ENDFOR)");
          $$ = StmtNode::createFor($3, $5, $7, StmtNode::createBlock($10));
      }
    | FOREACH '(' expr AS '$' ID ')' stmt {
          Console::ParserLog("stmt (FOREACH expr AS $ ID stmt)");
          $$ = StmtNode::createForeach($3, nullptr, ExprNode::createVar($6, false), $8);
      }
    | FOREACH '(' expr AS '&' '$' ID ')' stmt {
          Console::ParserLog("stmt (FOREACH expr AS & $ ID stmt)");
          $$ = StmtNode::createForeach($3, nullptr, ExprNode::createVar($7, true), $9);
      }
    | FOREACH '(' expr AS '[' foreach_array_items ']' ')' stmt {
          Console::ParserLog("stmt (FOREACH expr AS foreach_array_items stmt)");
          $$ = StmtNode::createForeach($3, nullptr, ExprNode::createArray($6), $9);
      }
    | FOREACH '(' expr AS '$' ID DOUBLE_ARROW is_reference '$' ID ')' stmt {
          Console::ParserLog("stmt (FOREACH expr AS $ ID DOUBLE_ARROW is_reference $ ID stmt)");
          $$ = StmtNode::createForeach($3, ExprNode::createVar($6, false), ExprNode::createVar($10, $8), $12);
      }
    | FOREACH '(' expr AS '$' ID ')' ':' stmt_list ENDFOREACH ';' {
          Console::ParserLog("stmt (FOREACH expr AS $ ID stmt_list ENDFOREACH)");
          $$ = StmtNode::createForeach($3, nullptr, ExprNode::createVar($6, false), StmtNode::createBlock($9));
      }
    | FOREACH '(' expr AS '&' '$' ID ')' ':' stmt_list ENDFOREACH ';' {
          Console::ParserLog("stmt (FOREACH expr AS & $ ID stmt_list ENDFOREACH)");
          $$ = StmtNode::createForeach($3, nullptr, ExprNode::createVar($7, true), StmtNode::createBlock($10));
      }
    | FOREACH '(' expr AS '[' foreach_array_items ']' ')' ':' stmt_list ENDFOREACH ';' {
          Console::ParserLog("stmt (FOREACH expr AS foreach_array_items stmt_list ENDFOREACH)");
          $$ = StmtNode::createForeach($3, nullptr, ExprNode::createArray($6), StmtNode::createBlock($10));
      }
    | FOREACH '(' expr AS '$' ID DOUBLE_ARROW is_reference '$' ID ')' ':' stmt_list ENDFOREACH ';' {
          Console::ParserLog("stmt (FOREACH expr AS $ ID DOUBLE_ARROW is_reference $ ID stmt_list ENDFOREACH)");
          $$ = StmtNode::createForeach($3, ExprNode::createVar($6, false), ExprNode::createVar($10, $8), StmtNode::createBlock($13));
      }
    | IF '(' expr ')' stmt else_if_stmts {
          Console::ParserLog("stmt (IF expr stmt else_if_stmts)");
          $$ = StmtNode::createIf($3, $5, $6, nullptr);
      }
    | IF '(' expr ')' stmt else_if_stmts ELSE stmt {
          Console::ParserLog("stmt (IF expr stmt else_if_stmts ELSE stmt)");
          $$ = StmtNode::createIf($3, $5, $6, $8);
      }
    | IF '(' expr ')' ':' stmt_list alt_else_if_stmts ENDIF ';' {
          Console::ParserLog("stmt (IF expr stmt_list alt_else_if_stmts ENDIF)");
          $$ = StmtNode::createIf($3, StmtNode::createBlock($6), $7, nullptr);
      }
    | IF '(' expr ')' ':' stmt_list alt_else_if_stmts ELSE ':' stmt_list ENDIF ';' {
          Console::ParserLog("stmt (IF expr stmt_list alt_else_if_stmts ELSE stmt_list ENDIF)");
          $$ = StmtNode::createIf($3, StmtNode::createBlock($6), $7, StmtNode::createBlock($10));
      }
    | SWITCH '(' expr ')' '{' case_list '}' {
          Console::ParserLog("stmt (SWITCH expr case_list)");
          $$ = StmtNode::createSwitch($3, $6);
      }
    | SWITCH '(' expr ')' '{' ';' case_list '}' {
          Console::ParserLog("stmt (SWITCH ; case_list)");
          $$ = StmtNode::createSwitch($3, $7);
      }
    | SWITCH '(' expr ')' ':' case_list ENDSWITCH ';' {
          Console::ParserLog("stmt (SWITCH expr case_list ENDSWITCH)");
          $$ = StmtNode::createSwitch($3, $6);
      }
    | SWITCH '(' expr ')' ':' ';' case_list ENDSWITCH ';' {
          Console::ParserLog("stmt (SWITCH ; case_list ENDSWITCH)");
          $$ = StmtNode::createSwitch($3, $7);
      }
    | TRY block catch_list_e {
          Console::ParserLog("stmt (TRY block catch_list_e)");
          $$ = StmtNode::createTry($2, $3, nullptr);
      }
    | TRY block catch_list_e FINALLY block {
          Console::ParserLog("stmt (TRY block catch_list_e FINALLY block)");
          $$ = StmtNode::createTry($2, $3, $5);
      }
    | error ';' {
          Console::ParserLog("stmt (error ;)");
          $$ = nullptr;
      }
    ;

block
    : '{' stmt_list '}' {
          Console::ParserLog("block ({ stmt_list })");
          $$ = StmtNode::createBlock($2);
      }
    ;

/* $a, $$a, $$$a, ${'a'.'b'} */
variable
    : '$' ID {
          Console::ParserLog("variable ($ ID)");
          $$ = ExprNode::createName(VarExpr, $2);
      }
    | '$' variable {
          Console::ParserLog("variable ($ variable)");
          $$ = ExprNode::createOp(VarVarExpr, $2);
      }
    | '$' '{' expr '}' {
          Console::ParserLog("variable (${ expr })");
          $$ = ExprNode::createOp(VarVarExpr, $3);
      }
    ;

expr
    : LNUMBER {
          Console::ParserLog("expr (LNUMBER)");
          $$ = ExprNode::createInt($1);
      }
    | DNUMBER {
          Console::ParserLog("expr (DNUMBER)");
          $$ = ExprNode::createFloat($1);
      }
    | CONSTANT_STRING {
          Console::ParserLog("expr (CONSTANT_STRING)");
          $$ = ExprNode::createString($1);
      }
    | TRUE {
          Console::ParserLog("expr (TRUE)");
          $$ = ExprNode::createSimple(TrueExpr);
      }
    | FALSE {
          Console::ParserLog("expr (FALSE)");
          $$ = ExprNode::createSimple(FalseExpr);
      }
    | NULLPTR {
          Console::ParserLog("expr (NULLPTR)");
          $$ = ExprNode::createSimple(NullExpr);
      }
    | ID {
          Console::ParserLog("expr (ID)");
          $$ = ExprNode::createName(ConstExpr, $1);
      }
    | SELF {
          Console::ParserLog("expr (SELF)");
          $$ = ExprNode::createSimple(SelfExpr);
      }
    | PARENT {
          Console::ParserLog("expr (PARENT)");
          $$ = ExprNode::createSimple(ParentExpr);
      }
    | STATIC {
          Console::ParserLog("expr (STATIC)");
          $$ = ExprNode::createSimple(StaticExpr);
      }
    | variable {
          Console::ParserLog("expr (variable)");
          $$ = $1;
      }
    | '(' expr ')' {
          Console::ParserLog("expr (( expr ))");
          $$ = $2;
      }
    | '[' array_items_opt ']' {
          Console::ParserLog("expr ([ array_items_opt ])");
          $$ = ExprNode::createArray($2);
      }
    | ARRAY '(' array_items_opt ')' {
          Console::ParserLog("expr (ARRAY array_items_opt)");
          $$ = ExprNode::createArray($3);
      }
    | expr '[' expr_e ']' {
          Console::ParserLog("expr (expr [ expr_e ])");
          $$ = ExprNode::createOp(IndexExpr, $1, $3);
      }
    | expr OBJECT_OPERATOR ID {
          Console::ParserLog("expr (expr OBJECT_OPERATOR ID)");
          $$ = ExprNode::createOp(PropExpr, $1, ExprNode::createName(NameExpr, $3));
      }
    | expr OBJECT_OPERATOR variable {
          Console::ParserLog("expr (expr OBJECT_OPERATOR variable)");
          $$ = ExprNode::createOp(PropExpr, $1, $3);
      }
    | expr OBJECT_OPERATOR '{' expr '}' {
          Console::ParserLog("expr (expr OBJECT_OPERATOR { expr })");
          $$ = ExprNode::createOp(PropExpr, $1, $4);
      }
    | expr NULLSAFE_OBJECT_OPERATOR ID {
          Console::ParserLog("expr (expr NULLSAFE_OBJECT_OPERATOR ID)");
          $$ = ExprNode::createOp(NullsafePropExpr, $1, ExprNode::createName(NameExpr, $3));
      }
    | expr NULLSAFE_OBJECT_OPERATOR variable {
          Console::ParserLog("expr (expr NULLSAFE_OBJECT_OPERATOR variable)");
          $$ = ExprNode::createOp(NullsafePropExpr, $1, $3);
      }
    | expr NULLSAFE_OBJECT_OPERATOR '{' expr '}' {
          Console::ParserLog("expr (expr NULLSAFE_OBJECT_OPERATOR { expr })");
          $$ = ExprNode::createOp(NullsafePropExpr, $1, $4);
      }
    | expr DOUBLE_COLON ID {
          Console::ParserLog("expr (expr DOUBLE_COLON ID)");
          $$ = ExprNode::createOp(StaticMemberExpr, $1, ExprNode::createName(NameExpr, $3));
      }
    | expr DOUBLE_COLON variable {
          Console::ParserLog("expr (expr DOUBLE_COLON variable)");
          $$ = ExprNode::createOp(StaticMemberExpr, $1, $3);
      }
    | expr '(' ')' {
          Console::ParserLog("expr (expr ())");
          $$ = ExprNode::createCall($1, nullptr);
      }
    | expr '(' argument_list possible_comma ')' {
          Console::ParserLog("expr (expr argument_list possible_comma)");
          $$ = ExprNode::createCall($1, $3);
      }
    | '&' expr %prec UNARY {
          Console::ParserLog("expr (& expr)");
          $$ = ExprNode::createOp(RefExpr, $2);
      }
    | expr '=' expr {
          Console::ParserLog("expr (expr = expr)");
          $$ = ExprNode::createOp(AssignExpr, $1, $3);
      }
    | expr PLUS_EQUAL expr {
          Console::ParserLog("expr (expr PLUS_EQUAL expr)");
          $$ = ExprNode::createOp(PlusAssignExpr, $1, $3);
      }
    | expr MINUS_EQUAL expr {
          Console::ParserLog("expr (expr MINUS_EQUAL expr)");
          $$ = ExprNode::createOp(MinusAssignExpr, $1, $3);
      }
    | expr MUL_EQUAL expr {
          Console::ParserLog("expr (expr MUL_EQUAL expr)");
          $$ = ExprNode::createOp(MulAssignExpr, $1, $3);
      }
    | expr DIV_EQUAL expr {
          Console::ParserLog("expr (expr DIV_EQUAL expr)");
          $$ = ExprNode::createOp(DivAssignExpr, $1, $3);
      }
    | expr CONCAT_EQUAL expr {
          Console::ParserLog("expr (expr CONCAT_EQUAL expr)");
          $$ = ExprNode::createOp(ConcatAssignExpr, $1, $3);
      }
    | expr MOD_EQUAL expr {
          Console::ParserLog("expr (expr MOD_EQUAL expr)");
          $$ = ExprNode::createOp(ModAssignExpr, $1, $3);
      }
    | expr POW_EQUAL expr {
          Console::ParserLog("expr (expr POW_EQUAL expr)");
          $$ = ExprNode::createOp(PowAssignExpr, $1, $3);
      }
    | expr AND_EQUAL expr {
          Console::ParserLog("expr (expr AND_EQUAL expr)");
          $$ = ExprNode::createOp(AndAssignExpr, $1, $3);
      }
    | expr OR_EQUAL expr {
          Console::ParserLog("expr (expr OR_EQUAL expr)");
          $$ = ExprNode::createOp(OrAssignExpr, $1, $3);
      }
    | expr XOR_EQUAL expr {
          Console::ParserLog("expr (expr XOR_EQUAL expr)");
          $$ = ExprNode::createOp(XorAssignExpr, $1, $3);
      }
    | expr SL_EQUAL expr {
          Console::ParserLog("expr (expr SL_EQUAL expr)");
          $$ = ExprNode::createOp(SlAssignExpr, $1, $3);
      }
    | expr SR_EQUAL expr {
          Console::ParserLog("expr (expr SR_EQUAL expr)");
          $$ = ExprNode::createOp(SrAssignExpr, $1, $3);
      }
    | expr COALESCE_EQUAL expr {
          Console::ParserLog("expr (expr COALESCE_EQUAL expr)");
          $$ = ExprNode::createOp(CoalesceAssignExpr, $1, $3);
      }
    | INC expr {
          Console::ParserLog("expr (INC expr)");
          $$ = ExprNode::createOp(PreIncExpr, $2);
      }
    | DEC expr {
          Console::ParserLog("expr (DEC expr)");
          $$ = ExprNode::createOp(PreDecExpr, $2);
      }
    | expr INC {
          Console::ParserLog("expr (expr INC)");
          $$ = ExprNode::createOp(PostIncExpr, $1);
      }
    | expr DEC {
          Console::ParserLog("expr (expr DEC)");
          $$ = ExprNode::createOp(PostDecExpr, $1);
      }
    | '-' expr %prec UNARY {
          Console::ParserLog("expr (- expr)");
          $$ = ExprNode::createOp(UMinusExpr, $2);
      }
    | '+' expr %prec UNARY {
          Console::ParserLog("expr (+ expr)");
          $$ = ExprNode::createOp(UPlusExpr, $2);
      }
    | '~' expr %prec UNARY {
          Console::ParserLog("expr (~ expr)");
          $$ = ExprNode::createOp(BitNotExpr, $2);
      }
    | '@' expr %prec UNARY {
          Console::ParserLog("expr (@ expr)");
          $$ = ExprNode::createOp(SilenceExpr, $2);
      }
    | '!' expr {
          Console::ParserLog("expr (! expr)");
          $$ = ExprNode::createOp(NotExpr, $2);
      }
    | expr '+' expr {
          Console::ParserLog("expr (expr + expr)");
          $$ = ExprNode::createOp(PlusExpr, $1, $3);
      }
    | expr '-' expr {
          Console::ParserLog("expr (expr - expr)");
          $$ = ExprNode::createOp(MinusExpr, $1, $3);
      }
    | expr '*' expr {
          Console::ParserLog("expr (expr * expr)");
          $$ = ExprNode::createOp(MulExpr, $1, $3);
      }
    | expr '/' expr {
          Console::ParserLog("expr (expr / expr)");
          $$ = ExprNode::createOp(DivExpr, $1, $3);
      }
    | expr '%' expr {
          Console::ParserLog("expr (expr % expr)");
          $$ = ExprNode::createOp(ModExpr, $1, $3);
      }
    | expr POW expr {
          Console::ParserLog("expr (expr POW expr)");
          $$ = ExprNode::createOp(PowExpr, $1, $3);
      }
    | expr '.' expr {
          Console::ParserLog("expr (expr . expr)");
          $$ = ExprNode::createOp(ConcatExpr, $1, $3);
      }
    | expr SL expr {
          Console::ParserLog("expr (expr SL expr)");
          $$ = ExprNode::createOp(SlExpr, $1, $3);
      }
    | expr SR expr {
          Console::ParserLog("expr (expr SR expr)");
          $$ = ExprNode::createOp(SrExpr, $1, $3);
      }
    | expr '&' expr {
          Console::ParserLog("expr (expr & expr)");
          $$ = ExprNode::createOp(BitAndExpr, $1, $3);
      }
    | expr '|' expr {
          Console::ParserLog("expr (expr | expr)");
          $$ = ExprNode::createOp(BitOrExpr, $1, $3);
      }
    | expr '^' expr {
          Console::ParserLog("expr (expr ^ expr)");
          $$ = ExprNode::createOp(BitXorExpr, $1, $3);
      }
    | expr '<' expr {
          Console::ParserLog("expr (expr < expr)");
          $$ = ExprNode::createOp(LessExpr, $1, $3);
      }
    | expr '>' expr {
          Console::ParserLog("expr (expr > expr)");
          $$ = ExprNode::createOp(GreaterExpr, $1, $3);
      }
    | expr IS_SMALLER_OR_EQUAL expr {
          Console::ParserLog("expr (expr IS_SMALLER_OR_EQUAL expr)");
          $$ = ExprNode::createOp(LessEqualExpr, $1, $3);
      }
    | expr IS_GREATER_OR_EQUAL expr {
          Console::ParserLog("expr (expr IS_GREATER_OR_EQUAL expr)");
          $$ = ExprNode::createOp(GreaterEqualExpr, $1, $3);
      }
    | expr IS_EQUAL expr {
          Console::ParserLog("expr (expr IS_EQUAL expr)");
          $$ = ExprNode::createOp(EqualExpr, $1, $3);
      }
    | expr IS_NOT_EQUAL expr {
          Console::ParserLog("expr (expr IS_NOT_EQUAL expr)");
          $$ = ExprNode::createOp(NotEqualExpr, $1, $3);
      }
    | expr IS_IDENTICAL expr {
          Console::ParserLog("expr (expr IS_IDENTICAL expr)");
          $$ = ExprNode::createOp(IdenticalExpr, $1, $3);
      }
    | expr IS_NOT_IDENTICAL expr {
          Console::ParserLog("expr (expr IS_NOT_IDENTICAL expr)");
          $$ = ExprNode::createOp(NotIdenticalExpr, $1, $3);
      }
    | expr SPACESHIP expr {
          Console::ParserLog("expr (expr SPACESHIP expr)");
          $$ = ExprNode::createOp(SpaceshipExpr, $1, $3);
      }
    | expr BOOLEAN_AND expr {
          Console::ParserLog("expr (expr BOOLEAN_AND expr)");
          $$ = ExprNode::createOp(BoolAndExpr, $1, $3);
      }
    | expr BOOLEAN_OR expr {
          Console::ParserLog("expr (expr BOOLEAN_OR expr)");
          $$ = ExprNode::createOp(BoolOrExpr, $1, $3);
      }
    | expr LOGICAL_AND expr {
          Console::ParserLog("expr (expr LOGICAL_AND expr)");
          $$ = ExprNode::createOp(LogicalAndExpr, $1, $3);
      }
    | expr LOGICAL_OR expr {
          Console::ParserLog("expr (expr LOGICAL_OR expr)");
          $$ = ExprNode::createOp(LogicalOrExpr, $1, $3);
      }
    | expr LOGICAL_XOR expr {
          Console::ParserLog("expr (expr LOGICAL_XOR expr)");
          $$ = ExprNode::createOp(LogicalXorExpr, $1, $3);
      }
    | expr '?' expr ':' expr {
          Console::ParserLog("expr (expr ? expr : expr)");
          $$ = ExprNode::createTernary($1, $3, $5);
      }
    | expr '?' ':' expr %prec SHORT_TERNARY {
          Console::ParserLog("expr (expr ? : expr)");
          $$ = ExprNode::createTernary($1, nullptr, $4);
      }
    | expr COALESCE expr {
          Console::ParserLog("expr (expr COALESCE expr)");
          $$ = ExprNode::createOp(CoalesceExpr, $1, $3);
      }
    | THROW expr {
          Console::ParserLog("expr (THROW expr)");
          $$ = ExprNode::createOp(ThrowExpr, $2);
      }
    | NEW expr {
          Console::ParserLog("expr (NEW expr)");
          $$ = ExprNode::createOp(NewExpr, $2);
      }
    | expr INSTANCEOF expr {
          Console::ParserLog("expr (expr INSTANCEOF expr)");
          $$ = ExprNode::createOp(InstanceofExpr, $1, $3);
      }
    ;

/* выражения через запятую: echo, заголовок for */
expr_list
    : expr {
          Console::ParserLog("expr_list (expr)");
          $$ = createList($1);
      }
    | expr_list ',' expr {
          Console::ParserLog("expr_list (expr_list , expr)");
          $$ = addToList($1, $3);
      }
    ;

/* необязательное выражение */
expr_e
    : %empty {
          Console::ParserLog("expr_e (empty)");
          $$ = nullptr;
      }
    | expr {
          Console::ParserLog("expr_e (expr)");
          $$ = $1;
      }
    ;

/* список элементов массива */
array_items_opt
    : %empty {
          Console::ParserLog("array_items_opt (empty)");
          $$ = createList<ExprNode*>();
      }
    | array_items {
          Console::ParserLog("array_items_opt (array_items)");
          $$ = $1;
      }
    | array_items ',' {
          Console::ParserLog("array_items_opt (array_items ,)");
          $$ = $1;
      }
    ;

array_items
    : expr {
          Console::ParserLog("array_items (expr)");
          $$ = createList($1);
      }
    | expr DOUBLE_ARROW expr {
          Console::ParserLog("array_items (expr DOUBLE_ARROW expr)");
          $$ = createList(ExprNode::createOp(ArrayPairExpr, $1, $3));
      }
    | ELLIPSIS expr {
          Console::ParserLog("array_items (ELLIPSIS expr)");
          $$ = createList(ExprNode::createOp(SpreadExpr, $2));
      }
    | array_items ',' expr {
          Console::ParserLog("array_items (array_items , expr)");
          $$ = addToList($1, $3);
      }
    | array_items ',' expr DOUBLE_ARROW expr {
          Console::ParserLog("array_items (array_items , expr DOUBLE_ARROW expr)");
          $$ = addToList($1, ExprNode::createOp(ArrayPairExpr, $3, $5));
      }
    | array_items ',' ELLIPSIS expr {
          Console::ParserLog("array_items (array_items , ELLIPSIS expr)");
          $$ = addToList($1, ExprNode::createOp(SpreadExpr, $4));
      }
    ;

/* цепочка elseif */
else_if_stmts
    : %empty {
          Console::ParserLog("else_if_stmts (empty)");
          $$ = createList<StmtNode*>();
      }
    | else_if_stmts ELSEIF '(' expr ')' stmt {
          Console::ParserLog("else_if_stmts (else_if_stmts ELSEIF expr stmt)");
          $$ = addToList($1, StmtNode::createElseIf($4, $6));
      }
    ;

/* альтернативный синтаксис elseif */
alt_else_if_stmts
    : %empty {
          Console::ParserLog("alt_else_if_stmts (empty)");
          $$ = createList<StmtNode*>();
      }
    | alt_else_if_stmts ELSEIF '(' expr ')' ':' stmt_list {
          Console::ParserLog("alt_else_if_stmts (alt_else_if_stmts ELSEIF expr stmt_list)");
          $$ = addToList($1, StmtNode::createElseIf($4, StmtNode::createBlock($7)));
      }
    ;

/* ветки switch */
case_list
    : %empty {
          Console::ParserLog("case_list (empty)");
          $$ = createList<StmtNode*>();
      }
    | case_list CASE expr ':' stmt_list {
          Console::ParserLog("case_list (case_list CASE expr stmt_list)");
          $$ = addToList($1, StmtNode::createCase($3, $5));
      }
    | case_list CASE expr ';' stmt_list {
          Console::ParserLog("case_list (case_list CASE expr ; stmt_list)");
          $$ = addToList($1, StmtNode::createCase($3, $5));
      }
    | case_list DEFAULT ':' stmt_list {
          Console::ParserLog("case_list (case_list DEFAULT stmt_list)");
          $$ = addToList($1, StmtNode::createCase(nullptr, $4));
      }
    | case_list DEFAULT ';' stmt_list {
          Console::ParserLog("case_list (case_list DEFAULT ; stmt_list)");
          $$ = addToList($1, StmtNode::createCase(nullptr, $4));
      }
    ;

for_exprs
    : %empty {
          Console::ParserLog("for_exprs (empty)");
          $$ = createList<ExprNode*>();
      }
    | expr_list {
          Console::ParserLog("for_exprs (expr_list)");
          $$ = $1;
      }
    ;

/* Элементы списка переменных foreach */
foreach_array_items
    : %empty {
          Console::ParserLog("foreach_array_items (empty)");
          $$ = createList<ExprNode*>();
      }
    | is_reference '$' ID {
          Console::ParserLog("foreach_array_items (is_reference $ ID)");
          $$ = createList(ExprNode::createVar($3, $1));
      }
    | foreach_array_items ',' is_reference '$' ID {
          Console::ParserLog("foreach_array_items (foreach_array_items , is_reference $ ID)");
          $$ = addToList($1, ExprNode::createVar($5, $3));
      }
    | foreach_array_items ',' {
          Console::ParserLog("foreach_array_items (foreach_array_items ,)");
          $$ = addToList<ExprNode*>($1, nullptr);
      }
    ;

/* список параметров */
parameter_list_e
    : %empty {
          Console::ParserLog("parameter_list_e (empty)");
          $$ = createList<ParamNode*>();
      }
    | parameter_list possible_comma {
          Console::ParserLog("parameter_list_e (parameter_list possible_comma)");
          $$ = $1;
      }
    ;

parameter_list
    : parameter {
          Console::ParserLog("parameter_list (parameter)");
          $$ = createList($1);
      }
    | parameter_list ',' parameter {
          Console::ParserLog("parameter_list (parameter_list , parameter)");
          $$ = addToList($1, $3);
      }
    ;

/* параметры */
parameter
    : modifiers_e type_e is_reference '$' ID {
          Console::ParserLog("parameter (modifiers_e type_e is_reference $ ID)");
          $$ = ParamNode::create($1, $2, $3, false, $5, nullptr);
      }
    | modifiers_e type_e is_reference '$' ID '=' expr {
          Console::ParserLog("parameter (modifiers_e type_e is_reference $ ID = expr)");
          $$ = ParamNode::create($1, $2, $3, false, $5, $7);
      }
    | modifiers_e type_e is_reference ELLIPSIS '$' ID {
          Console::ParserLog("parameter (modifiers_e type_e is_reference ELLIPSIS $ ID)");
          $$ = ParamNode::create($1, $2, $3, true, $6, nullptr);
      }
    ;

/* необязательный &: параметр по ссылке */
is_reference
    : %empty {
          Console::ParserLog("is_reference (empty)");
          $$ = false;
      }
    | '&' {
          Console::ParserLog("is_reference (&)");
          $$ = true;
      }
    ;

/* необязательный тип */
type_e
    : %empty {
          Console::ParserLog("type_e (empty)");
          $$ = nullptr;
      }
    | type {
          Console::ParserLog("type_e (type)");
          $$ = $1;
      }
    ;

/* необязательный тип возврата */
return_type
    : %empty {
          Console::ParserLog("return_type (empty)");
          $$ = nullptr;
      }
    | ':' type {
          Console::ParserLog("return_type (: type)");
          $$ = $2;
      }
    | ':' STATIC {
          Console::ParserLog("return_type (: STATIC)");
          $$ = TypeNode::create(new std::string("static"));
      }
    ;

/* тип */
type
    : type_name {
          Console::ParserLog("type (type_name)");
          $$ = TypeNode::create($1);
      }
    | '?' type_name {
          Console::ParserLog("type (? type_name)");
          $$ = TypeNode::create($2, true);
      }
    | type '|' type_name {
          Console::ParserLog("type (type | type_name)");
          $$ = TypeNode::addToUnion($1, $3);
      }
    ;

/* одно имя типа */
type_name
    : ARRAY {
          Console::ParserLog("type_name (ARRAY)");
          $$ = new std::string("array");
      }
    | NULLPTR {
          Console::ParserLog("type_name (NULLPTR)");
          $$ = new std::string("null");
      }
    | FALSE {
          Console::ParserLog("type_name (FALSE)");
          $$ = new std::string("false");
      }
    | TRUE {
          Console::ParserLog("type_name (TRUE)");
          $$ = new std::string("true");
      }
    | SELF {
          Console::ParserLog("type_name (SELF)");
          $$ = new std::string("self");
      }
    | PARENT {
          Console::ParserLog("type_name (PARENT)");
          $$ = new std::string("parent");
      }
    | ID {
          Console::ParserLog("type_name (ID)");
          $$ = $1;
      }
    ;

/* аргументы */
argument_list
    : expr {
          Console::ParserLog("argument_list (expr)");
          $$ = createList($1);
      }
    | ID ':' expr {
          Console::ParserLog("argument_list (ID : expr)");
          $$ = createList(ExprNode::createNamedArg($1, $3));
      }
    | ELLIPSIS expr {
          Console::ParserLog("argument_list (ELLIPSIS expr)");
          $$ = createList(ExprNode::createOp(SpreadExpr, $2));
      }
    | argument_list ',' expr {
          Console::ParserLog("argument_list (argument_list , expr)");
          $$ = addToList($1, $3);
      }
    | argument_list ',' ID ':' expr {
          Console::ParserLog("argument_list (argument_list , ID : expr)");
          $$ = addToList($1, ExprNode::createNamedArg($3, $5));
      }
    | argument_list ',' ELLIPSIS expr {
          Console::ParserLog("argument_list (argument_list , ELLIPSIS expr)");
          $$ = addToList($1, ExprNode::createOp(SpreadExpr, $4));
      }
    ;

/* catch */
catch_list_e
    : %empty {
          Console::ParserLog("catch_list_e (empty)");
          $$ = createList<StmtNode*>();
      }
    | catch_list_e CATCH '(' catch_types ')' block {
          Console::ParserLog("catch_list_e (catch_list_e CATCH catch_types block)");
          $$ = addToList($1, StmtNode::createCatch($4, nullptr, $6));
      }
    | catch_list_e CATCH '(' catch_types '$' ID ')' block {
          Console::ParserLog("catch_list_e (catch_list_e CATCH catch_types $ ID block)");
          $$ = addToList($1, StmtNode::createCatch($4, $6, $8));
      }
    ;

/* типы исключений в catch */
catch_types
    : ID {
          Console::ParserLog("catch_types (ID)");
          $$ = createList(*$1);
      }
    | catch_types '|' ID {
          Console::ParserLog("catch_types (catch_types | ID)");
          $$ = addToList($1, *$3);
      }
    ;

/* члены класса */
class_member_list
    : %empty {
          Console::ParserLog("class_member_list (empty)");
          $$ = createList<ClassMemberNode*>();
      }
    | class_member_list member_modifiers type_e property_list ';' {
          Console::ParserLog("class_member_list (class_member_list member_modifiers type_e property_list ;)");
          $$ = addToList($1, ClassMemberNode::createProperty($2, $3, $4));
      }
    | class_member_list VAR type_e property_list ';' {
          Console::ParserLog("class_member_list (class_member_list VAR type_e property_list ;)");
          $$ = addToList($1, ClassMemberNode::createProperty(ModPublic, $3, $4));
      }
    | class_member_list modifiers_e CONST const_list ';' {
          Console::ParserLog("class_member_list (class_member_list modifiers_e CONST const_list ;)");
          $$ = addToList($1, ClassMemberNode::createConst($2, $4));
      }
    | class_member_list modifiers_e FUNCTION is_reference identifier '(' parameter_list_e ')' return_type block {
          Console::ParserLog("class_member_list (class_member_list modifiers_e FUNCTION is_reference identifier parameter_list_e return_type block)");
          $$ = addToList($1, ClassMemberNode::createMethod($2, $4, $5, $7, $9, $10));
      }
    | class_member_list modifiers_e FUNCTION is_reference identifier '(' parameter_list_e ')' return_type ';' {
          Console::ParserLog("class_member_list (class_member_list modifiers_e FUNCTION is_reference identifier parameter_list_e return_type ;)");
          $$ = addToList($1, ClassMemberNode::createMethod($2, $4, $5, $7, $9, nullptr));
      }
    ;

/* свойства через запятую */
property_list
    : '$' ID {
          Console::ParserLog("property_list ($ ID)");
          $$ = createList(VarDeclNode::create($2, nullptr));
      }
    | '$' ID '=' expr {
          Console::ParserLog("property_list ($ ID = expr)");
          $$ = createList(VarDeclNode::create($2, $4));
      }
    | property_list ',' '$' ID {
          Console::ParserLog("property_list (property_list , $ ID)");
          $$ = addToList($1, VarDeclNode::create($4, nullptr));
      }
    | property_list ',' '$' ID '=' expr {
          Console::ParserLog("property_list (property_list , $ ID = expr)");
          $$ = addToList($1, VarDeclNode::create($4, $6));
      }
    ;

/* константы через запятую */
const_list
    : identifier '=' expr {
          Console::ParserLog("const_list (identifier = expr)");
          $$ = createList(VarDeclNode::create($1, $3));
      }
    | const_list ',' identifier '=' expr {
          Console::ParserLog("const_list (const_list , identifier = expr)");
          $$ = addToList($1, VarDeclNode::create($3, $5));
      }
    ;

/* имя метода или константы класса */
identifier
    : ID {
          Console::ParserLog("identifier (ID)");
          $$ = $1;
      }
    | ECHO_KW {
          Console::ParserLog("identifier (ECHO_KW)");
          $$ = new std::string("echo");
      }
    | ARRAY {
          Console::ParserLog("identifier (ARRAY)");
          $$ = new std::string("array");
      }
    | TRUE {
          Console::ParserLog("identifier (TRUE)");
          $$ = new std::string("true");
      }
    | FALSE {
          Console::ParserLog("identifier (FALSE)");
          $$ = new std::string("false");
      }
    | NULLPTR {
          Console::ParserLog("identifier (NULLPTR)");
          $$ = new std::string("null");
      }
    | AS {
          Console::ParserLog("identifier (AS)");
          $$ = new std::string("as");
      }
    | BREAK {
          Console::ParserLog("identifier (BREAK)");
          $$ = new std::string("break");
      }
    | CASE {
          Console::ParserLog("identifier (CASE)");
          $$ = new std::string("case");
      }
    | CATCH {
          Console::ParserLog("identifier (CATCH)");
          $$ = new std::string("catch");
      }
    | CLASS {
          Console::ParserLog("identifier (CLASS)");
          $$ = new std::string("class");
      }
    | CONST {
          Console::ParserLog("identifier (CONST)");
          $$ = new std::string("const");
      }
    | CONTINUE {
          Console::ParserLog("identifier (CONTINUE)");
          $$ = new std::string("continue");
      }
    | DEFAULT {
          Console::ParserLog("identifier (DEFAULT)");
          $$ = new std::string("default");
      }
    | DO {
          Console::ParserLog("identifier (DO)");
          $$ = new std::string("do");
      }
    | ELSE {
          Console::ParserLog("identifier (ELSE)");
          $$ = new std::string("else");
      }
    | ELSEIF {
          Console::ParserLog("identifier (ELSEIF)");
          $$ = new std::string("elseif");
      }
    | ENDFOR {
          Console::ParserLog("identifier (ENDFOR)");
          $$ = new std::string("endfor");
      }
    | ENDFOREACH {
          Console::ParserLog("identifier (ENDFOREACH)");
          $$ = new std::string("endforeach");
      }
    | ENDIF {
          Console::ParserLog("identifier (ENDIF)");
          $$ = new std::string("endif");
      }
    | ENDSWITCH {
          Console::ParserLog("identifier (ENDSWITCH)");
          $$ = new std::string("endswitch");
      }
    | ENDWHILE {
          Console::ParserLog("identifier (ENDWHILE)");
          $$ = new std::string("endwhile");
      }
    | EXTENDS {
          Console::ParserLog("identifier (EXTENDS)");
          $$ = new std::string("extends");
      }
    | FINALLY {
          Console::ParserLog("identifier (FINALLY)");
          $$ = new std::string("finally");
      }
    | FN {
          Console::ParserLog("identifier (FN)");
          $$ = new std::string("fn");
      }
    | FOR {
          Console::ParserLog("identifier (FOR)");
          $$ = new std::string("for");
      }
    | FOREACH {
          Console::ParserLog("identifier (FOREACH)");
          $$ = new std::string("foreach");
      }
    | FUNCTION {
          Console::ParserLog("identifier (FUNCTION)");
          $$ = new std::string("function");
      }
    | IF {
          Console::ParserLog("identifier (IF)");
          $$ = new std::string("if");
      }
    | INSTANCEOF {
          Console::ParserLog("identifier (INSTANCEOF)");
          $$ = new std::string("instanceof");
      }
    | NEW {
          Console::ParserLog("identifier (NEW)");
          $$ = new std::string("new");
      }
    | PRIVATE {
          Console::ParserLog("identifier (PRIVATE)");
          $$ = new std::string("private");
      }
    | PROTECTED {
          Console::ParserLog("identifier (PROTECTED)");
          $$ = new std::string("protected");
      }
    | PUBLIC {
          Console::ParserLog("identifier (PUBLIC)");
          $$ = new std::string("public");
      }
    | RETURN {
          Console::ParserLog("identifier (RETURN)");
          $$ = new std::string("return");
      }
    | STATIC {
          Console::ParserLog("identifier (STATIC)");
          $$ = new std::string("static");
      }
    | SWITCH {
          Console::ParserLog("identifier (SWITCH)");
          $$ = new std::string("switch");
      }
    | THROW {
          Console::ParserLog("identifier (THROW)");
          $$ = new std::string("throw");
      }
    | TRY {
          Console::ParserLog("identifier (TRY)");
          $$ = new std::string("try");
      }
    | USE {
          Console::ParserLog("identifier (USE)");
          $$ = new std::string("use");
      }
    | VAR {
          Console::ParserLog("identifier (VAR)");
          $$ = new std::string("var");
      }
    | WHILE {
          Console::ParserLog("identifier (WHILE)");
          $$ = new std::string("while");
      }
    | LOGICAL_AND {
          Console::ParserLog("identifier (LOGICAL_AND)");
          $$ = new std::string("and");
      }
    | LOGICAL_OR {
          Console::ParserLog("identifier (LOGICAL_OR)");
          $$ = new std::string("or");
      }
    | LOGICAL_XOR {
          Console::ParserLog("identifier (LOGICAL_XOR)");
          $$ = new std::string("xor");
      }
    ;

modifiers_e
    : %empty {
          Console::ParserLog("modifiers_e (empty)");
          $$ = NoModifier;
      }
    | member_modifiers {
          Console::ParserLog("modifiers_e (member_modifiers)");
          $$ = $1;
      }
    ;

member_modifiers
    : member_modifier {
          Console::ParserLog("member_modifiers (member_modifier)");
          $$ = $1;
      }
    | member_modifiers member_modifier {
          Console::ParserLog("member_modifiers (member_modifiers member_modifier)");
          $$ = $1 | $2;
      }
    ;

member_modifier
    : PUBLIC {
          Console::ParserLog("member_modifier (PUBLIC)");
          $$ = ModPublic;
      }
    | PROTECTED {
          Console::ParserLog("member_modifier (PROTECTED)");
          $$ = ModProtected;
      }
    | PRIVATE {
          Console::ParserLog("member_modifier (PRIVATE)");
          $$ = ModPrivate;
      }
    | STATIC {
          Console::ParserLog("member_modifier (STATIC)");
          $$ = ModStatic;
      }
    ;

/* необязательная запятая в конце списка */
possible_comma
    : %empty {
          Console::ParserLog("possible_comma (empty)");
      }
    | ',' {
          Console::ParserLog("possible_comma (, )");
      }
    ;

%%

void yyerror(const char* msg) {
    if (lastToken == ERROR) return;   /* лексер уже сообщил об этой ошибке */
    parserErrors++;
    Console::ParserError(yylineno, msg);
}