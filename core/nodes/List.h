#ifndef PHP_COMPILER_LIST_H
#define PHP_COMPILER_LIST_H

#include <vector>

/* Последовательности (операторы, аргументы, параметры, члены класса...) хранятся в std::vector.
   Леворекурсивное правило списка: первое правило создаёт список, рекурсивное - добавляет элемент.
       stmt_list : %empty          { $$ = createList<StmtNode*>(); }
                 | stmt_list stmt  { $$ = addToList($1, $2); }                                         */

template <class T>
std::vector<T>* createList() {
    return new std::vector<T>();
}

template <class T>
std::vector<T>* createList(T first) {
    std::vector<T>* result = new std::vector<T>();
    result->push_back(first);
    return result;
}

template <class T>
std::vector<T>* addToList(std::vector<T>* list, T item) {
    list->push_back(item);
    return list;
}

#endif //PHP_COMPILER_LIST_H
