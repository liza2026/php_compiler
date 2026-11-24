#include "StmtNode.h"

extern int yylineno;

StmtNode::StmtNode(StmtType type) : type(type), line(yylineno) {}

StmtNode* StmtNode::createEmpty() {
    return new StmtNode(EmptyStmt);
}

StmtNode* StmtNode::createExprStmt(ExprNode* expr) {
    StmtNode* result = new StmtNode(ExprStmt);
    result->expr = expr;
    return result;
}

StmtNode* StmtNode::createEcho(std::vector<ExprNode*>* exprs) {
    StmtNode* result = new StmtNode(EchoStmt);
    result->exprList = *exprs;
    return result;
}

StmtNode* StmtNode::createInlineHtml(std::string* html) {
    return createEcho(createList(ExprNode::createString(html)));
}

StmtNode* StmtNode::createBlock(std::vector<StmtNode*>* stmts) {
    StmtNode* result = new StmtNode(BlockStmt);
    result->stmts = *stmts;
    return result;
}

StmtNode* StmtNode::createJump(StmtType type, ExprNode* expr) {
    StmtNode* result = new StmtNode(type);
    result->expr = expr;
    return result;
}

StmtNode* StmtNode::createWhile(ExprNode* cond, StmtNode* body) {
    StmtNode* result = new StmtNode(WhileStmt);
    result->expr = cond;
    result->body = body;
    return result;
}

StmtNode* StmtNode::createDoWhile(StmtNode* body, ExprNode* cond) {
    StmtNode* result = createWhile(cond, body);
    result->type = DoWhileStmt;
    return result;
}

StmtNode* StmtNode::createFor(std::vector<ExprNode*>* init, std::vector<ExprNode*>* cond,
                              std::vector<ExprNode*>* step, StmtNode* body) {
    StmtNode* result = new StmtNode(ForStmt);
    result->forInit = *init;
    result->forCond = *cond;
    result->forStep = *step;
    result->body = body;
    return result;
}

StmtNode* StmtNode::createForeach(ExprNode* collection, ExprNode* key, ExprNode* value, StmtNode* body) {
    StmtNode* result = new StmtNode(ForeachStmt);
    result->expr = collection;
    result->foreachKey = key;
    result->foreachValue = value;
    result->body = body;
    return result;
}

StmtNode* StmtNode::createIf(ExprNode* cond, StmtNode* body, std::vector<StmtNode*>* elseIfs, StmtNode* elseBody) {
    StmtNode* result = new StmtNode(IfStmt);
    result->expr = cond;
    result->body = body;
    result->elseIfs = *elseIfs;
    result->elseBody = elseBody;
    return result;
}

StmtNode* StmtNode::createElseIf(ExprNode* cond, StmtNode* body) {
    StmtNode* result = createWhile(cond, body);
    result->type = ElseIfStmt;
    return result;
}

StmtNode* StmtNode::createSwitch(ExprNode* expr, std::vector<StmtNode*>* cases) {
    StmtNode* result = new StmtNode(SwitchStmt);
    result->expr = expr;
    result->cases = *cases;
    return result;
}

StmtNode* StmtNode::createCase(ExprNode* value, std::vector<StmtNode*>* stmts) {
    StmtNode* result = new StmtNode(value ? CaseStmt : DefaultStmt);
    result->expr = value;
    result->stmts = *stmts;
    return result;
}

StmtNode* StmtNode::createTry(StmtNode* body, std::vector<StmtNode*>* catches, StmtNode* finallyBody) {
    StmtNode* result = new StmtNode(TryStmt);
    result->body = body;
    result->catches = *catches;
    result->finallyBody = finallyBody;
    return result;
}

StmtNode* StmtNode::createCatch(std::vector<std::string>* types, std::string* var, StmtNode* body) {
    StmtNode* result = new StmtNode(CatchStmt);
    result->catchTypes = *types;
    if (var) result->catchVar = *var;
    result->body = body;
    return result;
}

StmtNode* StmtNode::createFunctionDecl(FunctionNode* function) {
    StmtNode* result = new StmtNode(FunctionDeclStmt);
    result->function = function;
    return result;
}

StmtNode* StmtNode::createClassDecl(ClassNode* classDecl) {
    StmtNode* result = new StmtNode(ClassDeclStmt);
    result->classDecl = classDecl;
    return result;
}

std::string stmtTypeName(StmtType type) {
    switch (type) {
        case EmptyStmt: return "empty ;";
        case ExprStmt: return "expr ;";
        case EchoStmt: return "echo";
        case BlockStmt: return "block { }";
        case BreakStmt: return "break";
        case ContinueStmt: return "continue";
        case ReturnStmt: return "return";
        case WhileStmt: return "while";
        case DoWhileStmt: return "do while";
        case ForStmt: return "for";
        case ForeachStmt: return "foreach";
        case IfStmt: return "if";
        case ElseIfStmt: return "elseif";
        case SwitchStmt: return "switch";
        case CaseStmt: return "case";
        case DefaultStmt: return "default";
        case TryStmt: return "try";
        case CatchStmt: return "catch";
        case FunctionDeclStmt: return "function";
        case ClassDeclStmt: return "class";
    }
    return "?";
}
