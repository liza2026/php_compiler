#ifndef PHP_COMPILER_TREEPRINTER_H
#define PHP_COMPILER_TREEPRINTER_H

#include <string>
#include <vector>
#include "StmtNode.h"

bool printTreeDot(const std::vector<StmtNode*>* program, const std::string& path);

#endif //PHP_COMPILER_TREEPRINTER_H
