#ifndef PHP_COMPILER_EXPRNODE_H
#define PHP_COMPILER_EXPRNODE_H

#include <string>
#include <vector>
#include "List.h"

enum ExprType {
    /* константы и имена */
    IntExpr,            // intValue
    FloatExpr,          // floatValue
    StringExpr,         // name - текст строки
    TrueExpr, FalseExpr, NullExpr,
    ConstExpr,          // name - имя без $: константа, функция или класс (Foo, strlen)
    NameExpr,           // name - имя члена класса после -> ?-> :: и имя именованного аргумента
    SelfExpr, ParentExpr, StaticExpr,

    /* переменные */
    VarExpr,            // name - $name
    VarVarExpr,         // operands[0] - $$x, ${expr}: имя переменной вычисляется

    /* массивы */
    ArrayExpr,          // operands - элементы [a, k => v, ...b]; nullptr - пропуск в [$a, , $b] foreach
    ArrayPairExpr,      // operands[0] => operands[1]
    SpreadExpr,         // ...operands[0]
    IndexExpr,          // operands[0][operands[1]]; у $a[] (добавление в конец) operands[1] нет

    /* обращение к членам класса: operands[0] - объект/класс, operands[1] - имя члена */
    PropExpr,           // ->
    NullsafePropExpr,   // ?->
    StaticMemberExpr,   // ::

    /* вызовы */
    CallExpr,           // operands[0] - что вызываем, далее аргументы
    NamedArgExpr,       // name: operands[0]
    NewExpr,            // operands[0] - класс, далее аргументы конструктора

    /* унарные: operands[0] */
    RefExpr,            // &
    UMinusExpr, UPlusExpr, NotExpr, BitNotExpr, SilenceExpr,
    PreIncExpr, PreDecExpr, PostIncExpr, PostDecExpr,
    ThrowExpr,

    /* бинарные: operands[0] op operands[1] */
    AssignExpr, PlusAssignExpr, MinusAssignExpr, MulAssignExpr, DivAssignExpr,
    ConcatAssignExpr, ModAssignExpr, PowAssignExpr, AndAssignExpr, OrAssignExpr,
    XorAssignExpr, SlAssignExpr, SrAssignExpr, CoalesceAssignExpr,
    PlusExpr, MinusExpr, MulExpr, DivExpr, ModExpr, PowExpr, ConcatExpr,
    SlExpr, SrExpr, BitAndExpr, BitOrExpr, BitXorExpr,
    LessExpr, GreaterExpr, LessEqualExpr, GreaterEqualExpr,
    EqualExpr, NotEqualExpr, IdenticalExpr, NotIdenticalExpr, SpaceshipExpr,
    BoolAndExpr, BoolOrExpr, LogicalAndExpr, LogicalOrExpr, LogicalXorExpr,
    CoalesceExpr, InstanceofExpr,

    /* тернарный: operands[0] ? operands[1] : operands[2]; operands[1] == nullptr для ?: */
    TernaryExpr
};

class ExprNode {
public:
    ExprType type;
    int line;           // строка, на которой выражение закончилось (для сообщений об ошибках)
    std::string name;
    long long intValue = 0;
    double floatValue = 0;
    std::vector<ExprNode*> operands;

    /* у new аргументы уже добавлены: new Foo()() - это вызов результата */
    bool hasArgs = false;

    explicit ExprNode(ExprType type);

    static ExprNode* createInt(long long value);
    static ExprNode* createFloat(double value);
    static ExprNode* createString(std::string* value);
    static ExprNode* createName(ExprType type, std::string* name);     // ConstExpr, NameExpr, VarExpr
    static ExprNode* createVar(std::string* name, bool byRef);         // $name или &$name (foreach)
    static ExprNode* createSimple(ExprType type);                      // true, false, null, self, parent, static
    static ExprNode* createOp(ExprType type, ExprNode* left, ExprNode* right = nullptr);
    static ExprNode* createTernary(ExprNode* cond, ExprNode* ifTrue, ExprNode* ifFalse);
    static ExprNode* createNamedArg(std::string* name, ExprNode* value);
    static ExprNode* createArray(std::vector<ExprNode*>* items);
    static ExprNode* createCall(ExprNode* callee, std::vector<ExprNode*>* args);
};

std::string exprTypeName(ExprType type);

#endif //PHP_COMPILER_EXPRNODE_H
