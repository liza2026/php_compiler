#include "DeclNode.h"

extern int yylineno;

std::string modifiersToString(int modifiers) {
    std::string result;
    if (modifiers & ModPublic) result += "public ";
    if (modifiers & ModProtected) result += "protected ";
    if (modifiers & ModPrivate) result += "private ";
    if (modifiers & ModStatic) result += "static ";
    return result;
}

TypeNode* TypeNode::create(std::string* name, bool nullable) {
    TypeNode* result = new TypeNode();
    result->names.push_back(*name);
    result->nullable = nullable;
    return result;
}

TypeNode* TypeNode::addToUnion(TypeNode* type, std::string* name) {
    type->names.push_back(*name);
    return type;
}

ParamNode* ParamNode::create(int modifiers, TypeNode* type, bool byRef, bool variadic,
                             std::string* name, ExprNode* defaultValue) {
    ParamNode* result = new ParamNode();
    result->modifiers = modifiers;
    result->type = type;
    result->byRef = byRef;
    result->variadic = variadic;
    result->name = *name;
    result->defaultValue = defaultValue;
    result->line = yylineno;
    return result;
}

FunctionNode* FunctionNode::create(bool byRefReturn, std::string* name, std::vector<ParamNode*>* params,
                                   TypeNode* returnType, StmtNode* body) {
    FunctionNode* result = new FunctionNode();
    result->byRefReturn = byRefReturn;
    result->name = *name;
    result->params = *params;
    result->returnType = returnType;
    result->body = body;
    result->line = yylineno;
    return result;
}

VarDeclNode* VarDeclNode::create(std::string* name, ExprNode* value) {
    VarDeclNode* result = new VarDeclNode();
    result->name = *name;
    result->value = value;
    return result;
}

ClassMemberNode* ClassMemberNode::createProperty(int modifiers, TypeNode* type, std::vector<VarDeclNode*>* vars) {
    ClassMemberNode* result = new ClassMemberNode();
    result->type = PropertyMember;
    result->modifiers = modifiers;
    result->varType = type;
    result->vars = *vars;
    return result;
}

ClassMemberNode* ClassMemberNode::createConst(int modifiers, std::vector<VarDeclNode*>* consts) {
    ClassMemberNode* result = createProperty(modifiers, nullptr, consts);
    result->type = ConstMember;
    return result;
}

ClassMemberNode* ClassMemberNode::createMethod(int modifiers, bool byRefReturn, std::string* name,
                                               std::vector<ParamNode*>* params, TypeNode* returnType, StmtNode* body) {
    ClassMemberNode* result = new ClassMemberNode();
    result->type = MethodMember;
    result->method = FunctionNode::create(byRefReturn, name, params, returnType, body);
    result->method->modifiers = modifiers;
    return result;
}

ClassNode* ClassNode::create(int modifiers, std::string* name, std::string* parent,
                             std::vector<ClassMemberNode*>* members) {
    ClassNode* result = new ClassNode();
    result->modifiers = modifiers;
    result->name = *name;
    if (parent) result->parent = *parent;
    result->members = *members;
    result->line = yylineno;
    return result;
}
