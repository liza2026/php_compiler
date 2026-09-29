#include "Buffer.h"

void Buffer::reset() {
    _content.clear();
    _startLine = -1;
}

void Buffer::append(const string& text) {
    _content += text;
}

void Buffer::setStartLine(int line) {
    _startLine = line;
}

int Buffer::getStartLine() const {
    return _startLine;
}

string Buffer::current() const {
    return _content;
}
