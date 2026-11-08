cmake_minimum_required(VERSION 3.25)
project(measure_guest C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_BUILD_TYPE MinSizeRel)

add_executable(measure.elf main.c)
target_include_directories(measure.elf PRIVATE ${CMAKE_SOURCE_DIR}/../api)

# Strip debug info only (never --strip-all): the host resolves guest
# functions through the symbol table, and --strip-all would empty it.
target_link_options(measure.elf PRIVATE -static -Wl,--strip-debug)
