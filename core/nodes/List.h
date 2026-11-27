#ifndef PHP_COMPILER_LIST_H
#define PHP_COMPILER_LIST_H

#include <vector>

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
