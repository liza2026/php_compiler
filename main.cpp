#include <cstdio>

#ifdef _WIN32
#include <windows.h>
#endif

#include "core/helpers/Console.h"

extern FILE* yyin;
extern int yyparse();
extern int yydebug;
extern int lexerErrors;
extern int parserErrors;

int main(int argc, char* argv[]) {

#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8);
#endif

    if (argc != 2) {
        fprintf(stderr, "Usage: %s <file_path>\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        fprintf(stderr, "Error opening file: %s\n", argv[1]);
        return 1;
    }

    yydebug = 0;
    int result = yyparse();

    fclose(yyin);

    if (result != 0 || lexerErrors > 0 || parserErrors > 0) {
        fprintf(stderr, "\nCompilation failed: %d lexer error(s), %d parser error(s)\n",
                lexerErrors, parserErrors);
        return 1;
    }
    printf("Parse OK\n");
    return 0;
}