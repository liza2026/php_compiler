#include "TreePrinter.h"
#include "DeclNode.h"

#include <fstream>
#include <sstream>

/* Каждая функция печатает узел и его потомков и возвращает номер узла,
   чтобы родитель мог провести к нему стрелку */
class DotPrinter {
public:
    explicit DotPrinter(std::ostream& out) : out(out) {}

    void program(const std::vector<StmtNode*>* stmts) {
        out << "digraph AST {\n"
            << "  node [fontname=\"Arial\", fontsize=11, style=filled];\n"
            << "  edge [fontname=\"Arial\", fontsize=9];\n";
        int id = node("program", "box", "#cfe8ff");
        for (StmtNode* s : *stmts) link(id, stmt(s));
        out << "}\n";
    }

private:
    std::ostream& out;
    int count = 0;

    static std::string escape(const std::string& text) {
        std::string result;
        for (char c : text) {
            if (c == '"' || c == '\\') { result += '\\'; result += c; }
            else if (c == '\n') result += "\\n";
            else if (c == '\r' || c == '\t') result += ' ';
            else result += c;
        }
        return result;
    }

    int node(const std::string& label, const char* shape, const char* color) {
        int id = count++;
        out << "  n" << id << " [label=\"" << escape(label) << "\", shape=" << shape
            << ", fillcolor=\"" << color << "\"];\n";
        return id;
    }

    /* пустой потомок (nullptr) не рисуется */
    void link(int from, int to, const std::string& label = "") {
        if (to < 0) return;
        out << "  n" << from << " -> n" << to;
        if (!label.empty()) out << " [label=\"" << escape(label) << "\"]";
        out << ";\n";
    }

    /* список потомков под отдельным узлом-заголовком (если список не пуст) */
    void exprList(int parent, const std::vector<ExprNode*>& list, const std::string& label) {
        if (list.empty()) return;
        int id = node(label, "box", "#eeeeee");
        link(parent, id);
        for (ExprNode* e : list) link(id, expr(e));
    }

    void stmtList(int parent, const std::vector<StmtNode*>& list, const std::string& label) {
        if (list.empty()) return;
        int id = node(label, "box", "#eeeeee");
        link(parent, id);
        for (StmtNode* s : list) link(id, stmt(s));
    }

    std::string typeLabel(const TypeNode* type) {
        std::string result = type->nullable ? "?" : "";
        for (size_t i = 0; i < type->names.size(); i++) result += (i ? "|" : "") + type->names[i];
        return result;
    }

    int expr(const ExprNode* e) {
        if (!e) return -1;
        std::string label = exprTypeName(e->type);
        switch (e->type) {
            case IntExpr: label += " " + std::to_string(e->intValue); break;
            case FloatExpr: { std::ostringstream s; s << e->floatValue; label += " " + s.str(); break; }
            case StringExpr: label += " \"" + e->name + "\""; break;
            case ConstExpr: case NameExpr: case NamedArgExpr: label += " " + e->name; break;
            case VarExpr: label += e->name; break;
            default: break;
        }
        int id = node(label, "ellipse", "#fff2cc");
        for (ExprNode* op : e->operands) link(id, expr(op));
        return id;
    }

    int stmt(const StmtNode* s) {
        if (!s) return -1;
        if (s->type == FunctionDeclStmt) return function(s->function);
        if (s->type == ClassDeclStmt) return classDecl(s->classDecl);

        std::string label = stmtTypeName(s->type);
        if (s->type == CatchStmt) {
            for (size_t i = 0; i < s->catchTypes.size(); i++) label += (i ? " | " : " ") + s->catchTypes[i];
            if (!s->catchVar.empty()) label += " $" + s->catchVar;
        }
        int id = node(label, "box", "#d9f2d0");

        link(id, expr(s->expr), s->type == ForeachStmt ? "collection" : "");
        exprList(id, s->exprList, "exprs");
        exprList(id, s->forInit, "init");
        exprList(id, s->forCond, "condition");
        exprList(id, s->forStep, "step");
        link(id, expr(s->foreachKey), "key");
        link(id, expr(s->foreachValue), "value");
        link(id, stmt(s->body), "body");
        for (StmtNode* child : s->stmts) link(id, stmt(child));
        for (StmtNode* child : s->elseIfs) link(id, stmt(child));
        link(id, stmt(s->elseBody), "else");
        for (StmtNode* child : s->cases) link(id, stmt(child));
        for (StmtNode* child : s->catches) link(id, stmt(child));
        link(id, stmt(s->finallyBody), "finally");
        return id;
    }

    int function(const FunctionNode* f) {
        std::string label = modifiersToString(f->modifiers) + "function " + (f->byRefReturn ? "&" : "") + f->name;
        if (f->returnType) label += " : " + typeLabel(f->returnType);
        int id = node(label, "box", "#cfe8ff");
        for (ParamNode* p : f->params) {
            std::string param = modifiersToString(p->modifiers);
            if (p->type) param += typeLabel(p->type) + " ";
            param += std::string(p->byRef ? "&" : "") + (p->variadic ? "..." : "") + "$" + p->name;
            int paramId = node("param " + param, "box", "#ead9f5");
            link(id, paramId);
            link(paramId, expr(p->defaultValue), "default");
        }
        link(id, stmt(f->body), "body");
        return id;
    }

    int classDecl(const ClassNode* c) {
        std::string label = modifiersToString(c->modifiers) + "class " + c->name;
        if (!c->parent.empty()) label += " extends " + c->parent;
        int id = node(label, "box", "#cfe8ff");
        for (ClassMemberNode* m : c->members) {
            if (m->type == MethodMember) {
                link(id, function(m->method));
                continue;
            }
            std::string memberLabel = modifiersToString(m->modifiers) + (m->type == ConstMember ? "const" : "property");
            if (m->varType) memberLabel += " " + typeLabel(m->varType);
            int memberId = node(memberLabel, "box", "#ead9f5");
            link(id, memberId);
            for (VarDeclNode* v : m->vars) {
                int varId = node((m->type == ConstMember ? "" : "$") + v->name, "box", "#ead9f5");
                link(memberId, varId);
                link(varId, expr(v->value), "value");
            }
        }
        return id;
    }
};

bool printTreeDot(const std::vector<StmtNode*>* program, const std::string& path) {
    std::ofstream out(path);
    if (!out) return false;
    DotPrinter(out).program(program);
    return true;
}
