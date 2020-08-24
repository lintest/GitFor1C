cmake_minimum_required(VERSION 3.12)

project(GitFor1C)
set(TARGET GitFor1C)

add_library(${TARGET} SHARED
	src/AddInNative.cpp
	src/AddInNative.def
	src/AddInNative.h
	src/FileFinder.cpp 
	src/FileFinder.h 
	src/GitManager.cpp 
	src/GitManager.h 
	src/stdafx.h)

target_compile_definitions(${TARGET} PRIVATE UNICODE _UNICODE)

target_include_directories(${TARGET} PRIVATE include)

if (UNIX)
	set(MySuffix1 "Lin")
	if (APPLE)
		set(MySuffix1 "Mac")
	endif(APPLE)
	if (TARGET_PLATFORM_32)
		set(MySuffix2 "32")
	else()
		set(MySuffix2 "64")
	endif()
else(UNIX)
	if (NOT MSVC)
		message(FATAL_ERROR "Must be compiled with MSVC on Windows")
	endif(NOT MSVC)
	set(MyPrefix "lib")
	set(MySuffix1 "Win")
endif(UNIX)

set_target_properties( ${PROJECT_NAME} PROPERTIES
	   OUTPUT_NAME ${MyPrefix}${PROJECT_NAME}${MySuffix1}${MySuffix2} 
	   POSITION_INDEPENDENT_CODE ON 
	   CXX_STANDARD_REQUIRED ON
	   CXX_STANDARD 17
   )

if (UNIX)
	if (TARGET_ARCH STREQUAL "x86")
		set(CMAKE_C_FLAGS "-m32 ${CMAKE_C_FLAGS}")
		set(CMAKE_CXX_FLAGS "-m32 ${CMAKE_CXX_FLAGS}")
	endif ()
else(UNIX)
	add_definitions(/MT)
	set(CMAKE_SUPPRESS_REGENERATION 1)
	set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "" FORCE)
	target_compile_definitions(${TARGET} PRIVATE _WINDOWS
			_SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING)
	target_compile_options(${TARGET} PRIVATE /utf-8)
endif(UNIX)

target_include_directories(${TARGET} PRIVATE libgit2-1.0.1/include)
set(EMBED_SSH_PATH "../../libssh2-1.9.0" CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(BUILD_CLAR OFF CACHE BOOL "" FORCE)
set(STATIC_CRT ON CACHE BOOL "" FORCE)
add_subdirectory(./libgit2-1.0.1)
target_link_libraries(${TARGET} git2)