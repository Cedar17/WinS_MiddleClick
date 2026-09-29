cmake_minimum_required(VERSION 3.20)
project(WinS_MiddleClick VERSION 1.0 LANGUAGES CXX RC)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT WIN32)
    message(FATAL_ERROR "WinS_MiddleClick supports Windows only.")
endif()

if(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
    set(WINSMC_ARCH "arm64")
elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "x64" OR CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(WINSMC_ARCH "x64")
else()
    message(FATAL_ERROR "Unsupported architecture. Build with -A x64 or -A ARM64.")
endif()

set(WINSMC_PRODUCT_NAME "WinS_MiddleClick-${WINSMC_ARCH}")
set(WINSMC_EXE_NAME "WinS_MiddleClick-${WINSMC_ARCH}")
set(WINSMC_RC "${CMAKE_CURRENT_BINARY_DIR}/WinS_MiddleClick_version.rc")

file(WRITE "${WINSMC_RC}"
"#include <windows.h>\n\n"
"VS_VERSION_INFO VERSIONINFO\n"
" FILEVERSION 1,0,0,0\n"
" PRODUCTVERSION 1,0,0,0\n"
" FILEFLAGSMASK 0x3fL\n"
"#ifdef _DEBUG\n"
" FILEFLAGS 0x1L\n"
"#else\n"
" FILEFLAGS 0x0L\n"
"#endif\n"
" FILEOS 0x40004L\n"
" FILETYPE 0x1L\n"
" FILESUBTYPE 0x0L\n"
"BEGIN\n"
"    BLOCK \"StringFileInfo\"\n"
"    BEGIN\n"
"        BLOCK \"040904B0\"\n"
"        BEGIN\n"
"            VALUE \"CompanyName\", \"Cedar17\"\n"
"            VALUE \"FileDescription\", \"Win+S to Middle Click\"\n"
"            VALUE \"FileVersion\", \"1.0\"\n"
"            VALUE \"InternalName\", \"${WINSMC_EXE_NAME}\"\n"
"            VALUE \"OriginalFilename\", \"${WINSMC_EXE_NAME}.exe\"\n"
"            VALUE \"ProductName\", \"${WINSMC_PRODUCT_NAME}\"\n"
"            VALUE \"ProductVersion\", \"1.0\"\n"
"        END\n"
"    END\n"
"    BLOCK \"VarFileInfo\"\n"
"    BEGIN\n"
"        VALUE \"Translation\", 0x0409, 1200\n"
"    END\n"
"END\n")

add_executable(WinS_MiddleClick WIN32
    src/main.cpp
    src/hook.cpp
    src/hook.hpp
    "${WINSMC_RC}"
)

target_compile_definitions(WinS_MiddleClick PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(WinS_MiddleClick PRIVATE user32 kernel32)
set_target_properties(WinS_MiddleClick PROPERTIES OUTPUT_NAME "${WINSMC_EXE_NAME}")

if(MSVC)
    target_compile_options(WinS_MiddleClick PRIVATE /W4 /permissive- /EHsc)
    set_property(TARGET WinS_MiddleClick PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()
