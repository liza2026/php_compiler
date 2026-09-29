#ifndef COMPILER_BUFFER_H
#define COMPILER_BUFFER_H

#include <string>

using std::string;

class Buffer {
private:
    string _content;
    int _startLine = -1;

public:
    void reset();

    void append(const string& text);

    void setStartLine(int line);

    int getStartLine() const;

    string current() const;
};

#endif // COMPILER_BUFFER_H
