#include <cstdio>

#ifdef _WIN32
#include <windows.h>
#endif

#include "core/helpers/Console.h"

extern FILE* yyin;
extern int yyparse();

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

    int result = yyparse();

    fclose(yyin);

    if (result == 0) {
        printf("Parse OK\n");
    }
    return result;
}
