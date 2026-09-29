#include "Console.h"

#include <iostream>

using std::cout;
using std::endl;

bool Console::hadErrors = false;

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

bool Console::HadErrors() {
    return hadErrors;
}
