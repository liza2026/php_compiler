#ifndef PHP_COMPILER_TREEPRINTER_H
#define PHP_COMPILER_TREEPRINTER_H

#include <string>
#include <vector>
#include "StmtNode.h"

/* Пишет синтаксическое дерево в файл формата Graphviz DOT.
   Картинка: dot -Tsvg ast.dot -o ast.svg (или вставить текст файла на сайт GraphvizOnline) */
bool printTreeDot(const std::vector<StmtNode*>* program, const std::string& path);

#endif //PHP_COMPILER_TREEPRINTER_H
