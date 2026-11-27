#ifndef PHP_COMPILER_STMTNODE_H
#define PHP_COMPILER_STMTNODE_H

#include <string>
#include <vector>
#include "ExprNode.h"
#include "List.h"

class FunctionNode;
class ClassNode;

enum StmtType {
    EmptyStmt,          // ;
    ExprStmt,           // expr
    EchoStmt,           // exprList (вне PHP-кода HTML - это echo одной строки)
    BlockStmt,          // stmts
    BreakStmt,          // expr - уровень выхода или nullptr
    ContinueStmt,       // expr - уровень или nullptr
    ReturnStmt,         // expr - значение или nullptr
    WhileStmt,          // expr - условие, body
    DoWhileStmt,        // body, expr - условие
    ForStmt,            // forInit, forCond, forStep (списки, могут быть пустыми), body
    ForeachStmt,        // expr - коллекция, foreachKey (или nullptr), foreachValue, body
    IfStmt,             // expr - условие, body, elseIfs, elseBody (или nullptr)
    ElseIfStmt,         // expr - условие, body
    SwitchStmt,         // expr, cases
    CaseStmt,           // expr - значение, stmts
    DefaultStmt,        // stmts
    TryStmt,            // body, catches, finallyBody (или nullptr)
    CatchStmt,          // catchTypes, catchVar (может быть пустым), body
    FunctionDeclStmt,   // function
    ClassDeclStmt       // classDecl
};

class StmtNode {
public:
    StmtType type;
    int line;

    ExprNode* expr = nullptr;
    std::vector<ExprNode*> exprList;

    std::vector<ExprNode*> forInit;
    std::vector<ExprNode*> forCond;
    std::vector<ExprNode*> forStep;

    ExprNode* foreachKey = nullptr;
    ExprNode* foreachValue = nullptr;     // $v, &$v или [$a, $b] (ArrayExpr)

    StmtNode* body = nullptr;
    std::vector<StmtNode*> stmts;
    std::vector<StmtNode*> elseIfs;
    StmtNode* elseBody = nullptr;
    std::vector<StmtNode*> cases;

    std::vector<StmtNode*> catches;
    std::vector<std::string> catchTypes;
    std::string catchVar;
    StmtNode* finallyBody = nullptr;

    FunctionNode* function = nullptr;
    ClassNode* classDecl = nullptr;

    explicit StmtNode(StmtType type);

    static StmtNode* createEmpty();
    static StmtNode* createExprStmt(ExprNode* expr);
    static StmtNode* createEcho(std::vector<ExprNode*>* exprs);
    static StmtNode* createInlineHtml(std::string* html);
    static StmtNode* createBlock(std::vector<StmtNode*>* stmts);
    static StmtNode* createJump(StmtType type, ExprNode* expr);       // break, continue, return
    static StmtNode* createWhile(ExprNode* cond, StmtNode* body);
    static StmtNode* createDoWhile(StmtNode* body, ExprNode* cond);
    static StmtNode* createFor(std::vector<ExprNode*>* init, std::vector<ExprNode*>* cond,
                               std::vector<ExprNode*>* step, StmtNode* body);
    static StmtNode* createForeach(ExprNode* collection, ExprNode* key, ExprNode* value, StmtNode* body);
    static StmtNode* createIf(ExprNode* cond, StmtNode* body, std::vector<StmtNode*>* elseIfs, StmtNode* elseBody);
    static StmtNode* createElseIf(ExprNode* cond, StmtNode* body);
    static StmtNode* createSwitch(ExprNode* expr, std::vector<StmtNode*>* cases);
    static StmtNode* createCase(ExprNode* value, std::vector<StmtNode*>* stmts);  // value == nullptr - default
    static StmtNode* createTry(StmtNode* body, std::vector<StmtNode*>* catches, StmtNode* finallyBody);
    static StmtNode* createCatch(std::vector<std::string>* types, std::string* var, StmtNode* body);
    static StmtNode* createFunctionDecl(FunctionNode* function);
    static StmtNode* createClassDecl(ClassNode* classDecl);
};

std::string stmtTypeName(StmtType type);

#endif //PHP_COMPILER_STMTNODE_H
