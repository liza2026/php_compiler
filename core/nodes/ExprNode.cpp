#include "ExprNode.h"

extern int yylineno;

ExprNode::ExprNode(ExprType type) : type(type), line(yylineno) {}

ExprNode* ExprNode::createInt(long long value) {
    ExprNode* result = new ExprNode(IntExpr);
    result->intValue = value;
    return result;
}

ExprNode* ExprNode::createFloat(double value) {
    ExprNode* result = new ExprNode(FloatExpr);
    result->floatValue = value;
    return result;
}

ExprNode* ExprNode::createString(std::string* value) {
    return createName(StringExpr, value);
}

ExprNode* ExprNode::createName(ExprType type, std::string* name) {
    ExprNode* result = new ExprNode(type);
    result->name = *name;
    return result;
}

ExprNode* ExprNode::createVar(std::string* name, bool byRef) {
    ExprNode* var = createName(VarExpr, name);
    return byRef ? createOp(RefExpr, var) : var;
}

ExprNode* ExprNode::createSimple(ExprType type) {
    return new ExprNode(type);
}

ExprNode* ExprNode::createOp(ExprType type, ExprNode* left, ExprNode* right) {
    ExprNode* result = new ExprNode(type);
    result->operands.push_back(left);
    if (right) result->operands.push_back(right);
    return result;
}

ExprNode* ExprNode::createTernary(ExprNode* cond, ExprNode* ifTrue, ExprNode* ifFalse) {
    ExprNode* result = new ExprNode(TernaryExpr);
    result->operands = {cond, ifTrue, ifFalse};
    return result;
}

ExprNode* ExprNode::createNamedArg(std::string* name, ExprNode* value) {
    ExprNode* result = createOp(NamedArgExpr, value);
    result->name = *name;
    return result;
}

ExprNode* ExprNode::createArray(std::vector<ExprNode*>* items) {
    ExprNode* result = new ExprNode(ArrayExpr);
    result->operands = *items;
    return result;
}

/* По приоритетам new сворачивается раньше скобок: new Foo(1) разбирается как (new Foo)(1).
   Поэтому аргументы, идущие сразу после new, переносим в узел new */
ExprNode* ExprNode::createCall(ExprNode* callee, std::vector<ExprNode*>* args) {
    ExprNode* result = callee;
    if (callee->type != NewExpr || callee->hasArgs) {
        result = new ExprNode(CallExpr);
        result->operands.push_back(callee);
    }
    result->hasArgs = true;
    if (args) result->operands.insert(result->operands.end(), args->begin(), args->end());
    return result;
}

std::string exprTypeName(ExprType type) {
    switch (type) {
        case IntExpr: return "int";
        case FloatExpr: return "float";
        case StringExpr: return "string";
        case TrueExpr: return "true";
        case FalseExpr: return "false";
        case NullExpr: return "null";
        case ConstExpr: return "name";
        case NameExpr: return "member name";
        case SelfExpr: return "self";
        case ParentExpr: return "parent";
        case StaticExpr: return "static";
        case VarExpr: return "$";
        case VarVarExpr: return "$ (variable variable)";
        case ArrayExpr: return "array [ ]";
        case ArrayPairExpr: return "=>";
        case SpreadExpr: return "...";
        case IndexExpr: return "[ ]";
        case PropExpr: return "->";
        case NullsafePropExpr: return "?->";
        case StaticMemberExpr: return "::";
        case CallExpr: return "call ( )";
        case NamedArgExpr: return "named arg";
        case NewExpr: return "new";
        case RefExpr: return "& (reference)";
        case UMinusExpr: return "- (unary)";
        case UPlusExpr: return "+ (unary)";
        case NotExpr: return "!";
        case BitNotExpr: return "~";
        case SilenceExpr: return "@";
        case PreIncExpr: return "++ (prefix)";
        case PreDecExpr: return "-- (prefix)";
        case PostIncExpr: return "++ (postfix)";
        case PostDecExpr: return "-- (postfix)";
        case ThrowExpr: return "throw";
        case AssignExpr: return "=";
        case PlusAssignExpr: return "+=";
        case MinusAssignExpr: return "-=";
        case MulAssignExpr: return "*=";
        case DivAssignExpr: return "/=";
        case ConcatAssignExpr: return ".=";
        case ModAssignExpr: return "%=";
        case PowAssignExpr: return "**=";
        case AndAssignExpr: return "&=";
        case OrAssignExpr: return "|=";
        case XorAssignExpr: return "^=";
        case SlAssignExpr: return "<<=";
        case SrAssignExpr: return ">>=";
        case CoalesceAssignExpr: return "?\?=";
        case PlusExpr: return "+";
        case MinusExpr: return "-";
        case MulExpr: return "*";
        case DivExpr: return "/";
        case ModExpr: return "%";
        case PowExpr: return "**";
        case ConcatExpr: return ".";
        case SlExpr: return "<<";
        case SrExpr: return ">>";
        case BitAndExpr: return "&";
        case BitOrExpr: return "|";
        case BitXorExpr: return "^";
        case LessExpr: return "<";
        case GreaterExpr: return ">";
        case LessEqualExpr: return "<=";
        case GreaterEqualExpr: return ">=";
        case EqualExpr: return "==";
        case NotEqualExpr: return "!=";
        case IdenticalExpr: return "===";
        case NotIdenticalExpr: return "!==";
        case SpaceshipExpr: return "<=>";
        case BoolAndExpr: return "&&";
        case BoolOrExpr: return "||";
        case LogicalAndExpr: return "and";
        case LogicalOrExpr: return "or";
        case LogicalXorExpr: return "xor";
        case CoalesceExpr: return "?\?";
        case InstanceofExpr: return "instanceof";
        case TernaryExpr: return "? :";
    }
    return "?";
}
