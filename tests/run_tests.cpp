// Прогон всех тестов парсера одной командой: tests/parser/valid и tests/parser/invalid.
//
// Собирается как отдельная цель run_tests (см. CMakeLists.txt). Путь к php_parser и к папке
// с тестами CMake подставляет сам, поэтому в CLion достаточно выбрать run_tests и нажать Run.
//
// Аргументы (необязательные, задаются в Edit Configurations -> Program arguments):
//   7 8 9   - прогнать только тесты этих пунктов карточки (по номеру в начале имени файла)
//   -v      - для упавших тестов показать последние строки вывода парсера
//
// valid   - PASS, если парсер завершился с кодом 0 и не сообщил об ошибке.
// invalid - PASS, если была ошибка (код возврата не 0, "Syntax error" или "ERROR:" от лексера).
//           Номер строки ошибки сверяется с эталоном PHP из первой строки теста "FAIL (line N, ...)".
//           Тест с пометкой "compile" - ошибка уровня компиляции PHP: грамматически он разбирается,
//           поэтому если парсер его принял, это не провал, а пометка COMPILE.

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <regex>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/wait.h>
#endif

namespace fs = std::filesystem;

#ifndef PARSER_EXE
#define PARSER_EXE ""
#endif
#ifndef TESTS_DIR
#define TESTS_DIR "tests/parser"
#endif

struct RunResult {
    int code;
    std::string output;
};

// Запускает парсер на одном файле и забирает весь его вывод (stdout и stderr) и код возврата
RunResult runParser(const fs::path& exe, const fs::path& file) {
    RunResult result{-1, ""};
    char buf[4096];
#ifdef _WIN32
    // cmd /c снимает внешние кавычки, поэтому вся команда оборачивается ещё в одну пару
    std::wstring cmd = L"\"\"" + exe.wstring() + L"\" \"" + file.wstring() + L"\" 2>&1\"";
    FILE* pipe = _wpopen(cmd.c_str(), L"r");
#else
    std::string cmd = "\"" + exe.string() + "\" \"" + file.string() + "\" 2>&1";
    FILE* pipe = popen(cmd.c_str(), "r");
#endif
    if (!pipe) {
        result.output = "не удалось запустить парсер";
        return result;
    }
    while (fgets(buf, sizeof(buf), pipe)) {
        result.output += buf;
    }
#ifdef _WIN32
    result.code = _pclose(pipe);
#else
    int status = pclose(pipe);
    result.code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
#endif
    return result;
}

bool hasError(const RunResult& r) {
    return r.code != 0
        || r.output.find("Syntax error") != std::string::npos
        || r.output.find("ERROR:") != std::string::npos;
}

// Номер строки ошибки из сообщения парсера или лексера, 0 - если не нашли
int errorLine(const std::string& output) {
    static const std::regex syntaxLine(R"(Syntax error at line (\d+))");
    static const std::regex lexerLine(R"(ERROR:.*?line (\d+))");
    std::smatch m;
    if (std::regex_search(output, m, syntaxLine) || std::regex_search(output, m, lexerLine)) {
        return std::stoi(m[1]);
    }
    return 0;
}

// Номер пункта карточки из имени файла "09_branches_1.php" -> 9, -1 - если номера нет
int itemOf(const std::string& name) {
    static const std::regex numbered(R"(^(\d+)_)");
    std::smatch m;
    return std::regex_search(name, m, numbered) ? std::stoi(m[1]) : -1;
}

std::string firstLine(const fs::path& file) {
    std::ifstream in(file);
    std::string line;
    std::getline(in, line);
    return line;
}

std::vector<std::string> lastLines(const std::string& text, size_t count) {
    std::vector<std::string> lines;
    std::istringstream in(text);
    std::string line;
    while (std::getline(in, line)) {
        if (!line.empty()) lines.push_back(line);
    }
    if (lines.size() > count) lines.erase(lines.begin(), lines.end() - count);
    return lines;
}

int main(int argc, char* argv[]) {
#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8);
#endif

    fs::path exe = PARSER_EXE;
    fs::path testsDir = TESTS_DIR;
    std::set<int> items;
    bool verbose = false;

    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "-v") {
            verbose = true;
        } else if (!arg.empty() && std::all_of(arg.begin(), arg.end(), [](unsigned char c) { return std::isdigit(c); })) {
            items.insert(std::stoi(arg));
        } else {
            exe = arg;   // путь к парсеру можно передать явно
        }
    }

    if (exe.empty() || !fs::exists(exe)) {
        std::cout << "Не найден php_parser: " << exe.string() << "\nСоберите проект или передайте путь к парсеру аргументом.\n";
        return 2;
    }

    static const std::regex header(R"(FAIL \(line (\d+), (parse|compile)\))");
    int pass = 0, fail = 0, compile = 0;

    for (const std::string kind : {"valid", "invalid"}) {
        std::vector<fs::path> files;
        for (const auto& entry : fs::directory_iterator(testsDir / kind)) {
            if (entry.path().extension() == ".php") files.push_back(entry.path());
        }
        std::sort(files.begin(), files.end());

        for (const auto& file : files) {
            std::string name = file.filename().string();
            if (!items.empty() && !items.count(itemOf(name))) continue;

            RunResult r = runParser(exe, file);
            std::smatch expected;
            std::string head = firstLine(file);
            bool hasHeader = std::regex_search(head, expected, header);

            std::string status, note;
            if (kind == "valid") {
                status = hasError(r) ? "FAIL" : "PASS";
                if (status == "FAIL") {
                    int line = errorLine(r.output);
                    note = line ? "ошибка в строке " + std::to_string(line) : "парсер не принял файл";
                }
            } else if (hasError(r)) {
                status = "PASS";
                int line = errorLine(r.output);
                if (hasHeader && line && line != std::stoi(expected[1])) {
                    note = "строка " + std::to_string(line) + ", у PHP " + expected[1].str();
                }
            } else if (hasHeader && expected[2] == "compile") {
                status = "COMPILE";
                note = "ошибка уровня компиляции, грамматика её пропускает";
            } else {
                status = "FAIL";
                note = "ошибка не обнаружена";
            }

            if (status == "PASS") pass++;
            else if (status == "FAIL") fail++;
            else compile++;

            std::cout << std::left << std::setw(9) << status << std::setw(9) << kind
                      << std::setw(36) << name << note << "\n";
            if (verbose && status == "FAIL") {
                for (const auto& line : lastLines(r.output, 5)) std::cout << "           | " << line << "\n";
            }
        }
    }

    std::cout << "\nPASS " << pass << "  FAIL " << fail << "  COMPILE " << compile << "\n";
    return fail ? 1 : 0;
}
