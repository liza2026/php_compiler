cmake_minimum_required(VERSION 3.16)
project(php_parser CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(FLEX REQUIRED)
find_package(BISON REQUIRED)

FLEX_TARGET(Lexer ${CMAKE_SOURCE_DIR}/lexer.l ${CMAKE_BINARY_DIR}/lex.yy.cpp)
BISON_TARGET(Parser ${CMAKE_SOURCE_DIR}/parser.y ${CMAKE_BINARY_DIR}/parser.tab.cpp
        DEFINES_FILE ${CMAKE_BINARY_DIR}/parser.tab.hpp)
ADD_FLEX_BISON_DEPENDENCY(Lexer Parser)

add_executable(php_parser
        main.cpp
        core/helpers/Console.cpp
        core/helpers/Buffer.cpp
        ${FLEX_Lexer_OUTPUTS}
        ${BISON_Parser_OUTPUTS}
)

target_include_directories(php_parser PRIVATE ${CMAKE_SOURCE_DIR} ${CMAKE_BINARY_DIR})