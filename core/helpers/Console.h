#ifndef COMPILER_CONSOLE_H
#define COMPILER_CONSOLE_H

#include <string>

using std::string;

class Console {
public:
    // General messages
    static void Log(const string& message);
    static void Warning(const string& message);
    static void Error(const string& message);

    // Lexer messages
    static void LexLog(int line, const string& message);
    static void LexError(int line, const string& message);

    // Parser messages
    static void ParserLog(const string& message);
    static void ParserError(int line, const string& message);

    static bool HadErrors();

private:
    static bool hadErrors;
};

#endif // COMPILER_CONSOLE_H
