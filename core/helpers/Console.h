#ifndef COMPILER_CONSOLE_H
#define COMPILER_CONSOLE_H

#include <string>

using std::string;

class Console {
public:
    static void Log(const string& message);
    static void Warning(const string& message);
    static void Error(const string& message);
    static bool HadErrors();

private:
    static bool hadErrors;
};

#endif // COMPILER_CONSOLE_H
