#include "Console.h"

#include <iostream>

using std::cout;
using std::endl;

bool Console::hadErrors = false;

// General messages

void Console::Log(const string& message) {
    cout << message << endl;
}

void Console::Warning(const string& message) {
    cout << "WARNING: " << message << endl;
}

void Console::Error(const string& message) {
    hadErrors = true;
    cout << "ERROR: " << message << endl;
}

// Lexer messages

void Console::LexLog(int line, const string& message) {
#ifdef CONSOLE_LEXER_LOG_ENABLED
    cout << "[LEXER] Line " << line << ": "
         << message << endl;
#endif
}

void Console::LexError(int line, const string& message) {
    hadErrors = true;
    cout << "[LEXER ERROR] Line " << line << ": "
         << message << endl;
}

// Parser messages

void Console::ParserLog(const string& message) {
#ifdef CONSOLE_PARSER_LOG_ENABLED
    cout << "[PARSER] " << message << endl;
#endif
}

void Console::ParserError(int line, const string& message) {
    hadErrors = true;
    cout << "[PARSER ERROR] Line " << line << ": "
         << message << endl;
}

// Error state

bool Console::HadErrors() {
    return hadErrors;
}
