cmake_minimum_required(VERSION 3.16)
project(php_lexer)

set(CMAKE_CXX_STANDARD 11)

find_program(FLEX_EXECUTABLE flex)
if (NOT FLEX_EXECUTABLE)
    message(FATAL_ERROR "Flex not found! Install flex and try again.")
endif ()

set(SOURCE_LEXER_FILE "${CMAKE_SOURCE_DIR}/lexer.l")
set(GENERATED_LEXER_FILE "${CMAKE_CURRENT_BINARY_DIR}/lex.yy.cpp")

add_custom_command(
        OUTPUT ${GENERATED_LEXER_FILE}
        COMMAND ${FLEX_EXECUTABLE} -o ${GENERATED_LEXER_FILE} ${SOURCE_LEXER_FILE}
        DEPENDS ${SOURCE_LEXER_FILE}
        COMMENT "Generating C++ lexer with Flex"
)

set(CORE_SOURCES
        core/helpers/Console.cpp
        core/helpers/Buffer.cpp
)

set(MAIN_SOURCES
        main.cpp
)

add_executable(php_lexer
        ${MAIN_SOURCES}
        ${CORE_SOURCES}
        ${GENERATED_LEXER_FILE}
)

set_source_files_properties(${GENERATED_LEXER_FILE} PROPERTIES LANGUAGE CXX)

target_include_directories(php_lexer PRIVATE ${CMAKE_SOURCE_DIR})
