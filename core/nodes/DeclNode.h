#ifndef PHP_COMPILER_DECLNODE_H
#define PHP_COMPILER_DECLNODE_H

#include <string>
#include <vector>
#include "ExprNode.h"
#include "StmtNode.h"
#include "List.h"

/* Модификаторы - битовые флаги, у члена класса их может быть несколько: public static */
enum Modifier {
    NoModifier  = 0,
    ModPublic    = 1,
    ModProtected = 2,
    ModPrivate   = 4,
    ModStatic    = 8
};

std::string modifiersToString(int modifiers);

/* Тип: int, ?Foo, int|string|null. names - имена в объединении, nullable - знак ? */
class TypeNode {
public:
    std::vector<std::string> names;
    bool nullable = false;

    static TypeNode* create(std::string* name, bool nullable = false);
    static TypeNode* addToUnion(TypeNode* type, std::string* name);
};

/* Параметр функции: [модификаторы] [тип] [&] [...] $name [= значение по умолчанию].
   Модификаторы бывают только у параметров конструктора (сразу объявляют свойство) */
class ParamNode {
public:
    int modifiers = NoModifier;
    TypeNode* type = nullptr;
    bool byRef = false;
    bool variadic = false;
    std::string name;
    ExprNode* defaultValue = nullptr;
    int line;

    static ParamNode* create(int modifiers, TypeNode* type, bool byRef, bool variadic,
                             std::string* name, ExprNode* defaultValue);
};

/* Функция или метод. body == nullptr у метода без тела: function f();
   modifiers - только у методов */
class FunctionNode {
public:
    std::string name;
    int modifiers = NoModifier;
    bool byRefReturn = false;
    std::vector<ParamNode*> params;
    TypeNode* returnType = nullptr;
    StmtNode* body = nullptr;
    int line;

    static FunctionNode* create(bool byRefReturn, std::string* name, std::vector<ParamNode*>* params,
                                TypeNode* returnType, StmtNode* body);
};

/* Свойство или константа класса: имя и необязательное начальное значение */
class VarDeclNode {
public:
    std::string name;
    ExprNode* value = nullptr;

    static VarDeclNode* create(std::string* name, ExprNode* value);
};

enum MemberType {
    PropertyMember,     // modifiers, varType, vars
    ConstMember,        // modifiers, vars
    MethodMember        // method (модификаторы - в method->modifiers)
};

class ClassMemberNode {
public:
    MemberType type;
    int modifiers = NoModifier;
    TypeNode* varType = nullptr;
    std::vector<VarDeclNode*> vars;
    FunctionNode* method = nullptr;

    static ClassMemberNode* createProperty(int modifiers, TypeNode* type, std::vector<VarDeclNode*>* vars);
    static ClassMemberNode* createConst(int modifiers, std::vector<VarDeclNode*>* consts);
    static ClassMemberNode* createMethod(int modifiers, bool byRefReturn, std::string* name,
                                         std::vector<ParamNode*>* params, TypeNode* returnType, StmtNode* body);
};

class ClassNode {
public:
    int modifiers = NoModifier;
    std::string name;
    std::string parent;          // пусто, если нет extends
    std::vector<ClassMemberNode*> members;
    int line;

    static ClassNode* create(int modifiers, std::string* name, std::string* parent,
                             std::vector<ClassMemberNode*>* members);
};

#endif //PHP_COMPILER_DECLNODE_H
