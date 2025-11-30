# MIT License
# Copyright...
cmake_minimum_required(VERSION 3.20)

message(CHECK_START "Version.cmake")
list(APPEND CMAKE_MESSAGE_INDENT "  ")

# Prefix dla exportowanych zmiennych i targetów
if(NOT DEFINED VERSION_PREFIX)
    set(VERSION_PREFIX "" CACHE STRING "Prefix for generated version variables and targets")
endif()

# Nazwy targetów zależne od prefixu
if(VERSION_PREFIX STREQUAL "")
    set(_VERSION_TARGET_GEN   "genCmakeVersion")
    set(_VERSION_TARGET_IFACE "cmakeVersion")
    set(_VERSION_ALIAS        "version::version")
else()
    set(_VERSION_TARGET_GEN   "${VERSION_PREFIX}_genCmakeVersion")
    set(_VERSION_TARGET_IFACE "${VERSION_PREFIX}_cmakeVersion")
    set(_VERSION_ALIAS        "${VERSION_PREFIX}::version")
endif()

# Gdzie generujemy nagłówek (możesz nadpisać przed include)
if(VERSION_PREFIX STREQUAL "")
    set(_OUT_DIR_VAR    "VERSION_OUT_DIR")
    set(_SRC_DIR_VAR    "VERSION_SOURCE_DIR")
else()
    set(_OUT_DIR_VAR    "${VERSION_PREFIX}_VERSION_OUT_DIR")
    set(_SRC_DIR_VAR    "${VERSION_PREFIX}_VERSION_SOURCE_DIR")
endif()

# Gdzie generujemy nagłówek
if(NOT DEFINED ${_OUT_DIR_VAR})
    set(${_OUT_DIR_VAR} "${CMAKE_BINARY_DIR}" CACHE PATH
        "Destination directory into which Version.cmake shall generate ${VERSION_PREFIX}Version.h")
endif()

# Skąd bierzemy repo (domyślnie root projektu)
if(NOT DEFINED ${_SRC_DIR_VAR})
    set(${_SRC_DIR_VAR} "${CMAKE_CURRENT_SOURCE_DIR}" CACHE PATH
        "Repository directory used for Version.cmake repo versioning (${VERSION_PREFIX})")
endif()

# Lokalne „skrótowe” zmienne używane w reszcie skryptu
set(VERSION_OUT_DIR    "${${_OUT_DIR_VAR}}")
set(VERSION_SOURCE_DIR "${${_SRC_DIR_VAR}}")

# ---------- Git ----------

message(CHECK_START "Find git")
if(NOT DEFINED GIT_EXECUTABLE)
    find_package(Git)
    if(NOT Git_FOUND)
        message(CHECK_FAIL "Not found in PATH")
    else()
        message(CHECK_PASS "Found: '${GIT_EXECUTABLE}'")
    endif()
else()
    message(CHECK_PASS "Using pre-defined GIT_EXECUTABLE: '${GIT_EXECUTABLE}'")
endif()

# describe: np. v1.0.0-1-g23fe208-dirty
set(_GIT_VERSION_COMMAND
    "${GIT_EXECUTABLE}" -C "${VERSION_SOURCE_DIR}"
    --no-pager describe --tags
    --exclude "v[0-9]*[._][0-9]*[._][0-9]*-[0-9]*"
    --always --dirty --long
)

# count commitów
set(_GIT_COUNT_COMMAND
    "${GIT_EXECUTABLE}" -C "${VERSION_SOURCE_DIR}"
    rev-list --count --first-parent HEAD
)

# git dir
set(_GIT_CACHE_PATH_COMMAND
    "${GIT_EXECUTABLE}" -C "${VERSION_SOURCE_DIR}" rev-parse --git-dir
)

# ---------- Parsowanie semver ----------

macro(version_parseSemantic semVer)
    if("${semVer}" MATCHES "^v?([0-9]+)[._]([0-9]+)[._]?([0-9]+)?[-]([0-9]+)[-][g]([._0-9A-Fa-f]+)[-]?(dirty)?$")
        set(_VERSION_SET TRUE)
        math(EXPR _VERSION_MAJOR  "${CMAKE_MATCH_1}+0")
        math(EXPR _VERSION_MINOR  "${CMAKE_MATCH_2}+0")
        math(EXPR _VERSION_PATCH  "${CMAKE_MATCH_3}+0")
        math(EXPR _VERSION_COMMIT "${CMAKE_MATCH_4}+0")
        set(_VERSION_SHA   "${CMAKE_MATCH_5}")
        set(_VERSION_DIRTY "${CMAKE_MATCH_6}")
        set(_VERSION_SEMANTIC
            "${_VERSION_MAJOR}.${_VERSION_MINOR}.${_VERSION_PATCH}.${_VERSION_COMMIT}")
        set(_VERSION_FULL "${semVer}")
        if("${VERSION_PREFIX}" STREQUAL "")
            set(_VERSION_PREFIX "")
        else()
            set(_VERSION_PREFIX "${VERSION_PREFIX}_")
        endif()
    else()
        set(_VERSION_SET FALSE)
    endif()
endmacro()

# Export do zmiennych z prefixem, np. TE_VERSION_FULL, TE_VERSION_SEMANTIC
macro(version_export_variables)
    if(NOT DEFINED VERSION_PREFIX OR VERSION_PREFIX STREQUAL "")
        set(_NS "")
    else()
        set(_NS "${VERSION_PREFIX}_")
    endif()

    # _VERSION_* to wewnętrzne zmienne z version_parseSemantic()
    set(${_NS}VERSION_SET      ${_VERSION_SET}      CACHE INTERNAL "" FORCE)
    set(${_NS}VERSION_MAJOR    ${_VERSION_MAJOR}    CACHE INTERNAL "" FORCE)
    set(${_NS}VERSION_MINOR    ${_VERSION_MINOR}    CACHE INTERNAL "" FORCE)
    set(${_NS}VERSION_PATCH    ${_VERSION_PATCH}    CACHE INTERNAL "" FORCE)
    set(${_NS}VERSION_COMMIT   ${_VERSION_COMMIT}   CACHE INTERNAL "" FORCE)
    set(${_NS}VERSION_SHA      ${_VERSION_SHA}      CACHE INTERNAL "" FORCE)
    set(${_NS}VERSION_DIRTY    ${_VERSION_DIRTY}    CACHE INTERNAL "" FORCE)
    set(${_NS}VERSION_SEMANTIC ${_VERSION_SEMANTIC} CACHE INTERNAL "" FORCE)
    set(${_NS}VERSION_FULL     ${_VERSION_FULL}     CACHE INTERNAL "" FORCE)
endmacro()

# ---------- Git cache path ----------

message(CHECK_START "Git Cache-Path")
execute_process(
    COMMAND           ${_GIT_CACHE_PATH_COMMAND}
    RESULT_VARIABLE   _GIT_RESULT
    OUTPUT_VARIABLE   _GIT_CACHE_PATH
    ERROR_VARIABLE    _GIT_ERROR
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
)
if(NOT _GIT_RESULT EQUAL 0)
    message(CHECK_FAIL "Failed: ${_GIT_CACHE_PATH_COMMAND}\n"
                       "RESULT_VARIABLE:'${_GIT_RESULT}'\n"
                       "OUTPUT_VARIABLE:'${_GIT_CACHE_PATH}'\n"
                       "ERROR_VARIABLE:'${_GIT_ERROR}'")
else()
    file(TO_CMAKE_PATH "${VERSION_SOURCE_DIR}/${_GIT_CACHE_PATH}" _GIT_CACHE_PATH)
    message(CHECK_PASS "Success '${_GIT_CACHE_PATH}'")
endif()

# ---------- Git describe ----------

message(CHECK_START "Git Describe")
execute_process(
    COMMAND           ${_GIT_VERSION_COMMAND}
    RESULT_VARIABLE   _GIT_RESULT
    OUTPUT_VARIABLE   _GIT_DESCRIBE
    ERROR_VARIABLE    _GIT_ERROR
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
)
if(NOT _GIT_RESULT EQUAL 0)
    message(CHECK_FAIL "Failed: ${_GIT_VERSION_COMMAND}\n"
                       "Result:'${_GIT_RESULT}' Error:'${_GIT_ERROR}'")
    if("${_GIT_ERROR}" STREQUAL "fatal: bad revision 'HEAD'")
        set(_VERSION_NOT_GIT_REPO TRUE)
    endif()
else()
    message(CHECK_PASS "Success '${_GIT_DESCRIBE}'")
    message(CHECK_START "Parse version")
    version_parseSemantic("${_GIT_DESCRIBE}")
    if(_VERSION_SET)
        message(CHECK_PASS "Tag '${_GIT_DESCRIBE}' is a valid semantic version [${_VERSION_SEMANTIC}]")
    else()
        message(CHECK_FAIL "'${_GIT_DESCRIBE}' is not a valid semantic-version e.g. 'v0.1.2-30'")
    endif()
endif()

# ---------- Fallback na git count ----------

if(NOT DEFINED _VERSION_FULL AND NOT _VERSION_NOT_GIT_REPO)
    message(CHECK_START "Fallback as Git-Count")
    execute_process(
        COMMAND           ${_GIT_COUNT_COMMAND}
        RESULT_VARIABLE   _GIT_RESULT
        OUTPUT_VARIABLE   _GIT_COUNT
        ERROR_VARIABLE    _GIT_ERROR
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE
    )
    if(NOT _GIT_RESULT EQUAL 0)
        message(CHECK_FAIL "Failed: ${_GIT_COUNT_COMMAND}\n"
                           "Result:'${_GIT_RESULT}' Error:'${_GIT_ERROR}'")
    else()
        set(_GIT_DESCRIBE "0.0.0-${_GIT_COUNT}-g${_GIT_DESCRIBE}")
        version_parseSemantic("${_GIT_DESCRIBE}")
        if(_VERSION_SET)
            message(CHECK_PASS "git-tag '${_GIT_DESCRIBE}' is a valid semantic version")
        else()
            message(CHECK_FAIL "'${_GIT_DESCRIBE}' is not a valid semantic-version e.g. 'v0.1.2-30'")
        endif()
    endif()
endif()

# ---------- Generacja nagłówka ----------

function(gitversion_configure_file VERSION_H_TEMPLATE VERSION_H)
    configure_file("${VERSION_H_TEMPLATE}" "${VERSION_H}")
endfunction()

version_export_variables()  # eksportuje TE_VERSION_* itd.

if(VERSION_GENERATE_NOW)
    # Tryb jednokrotnego odpalenia z zewnętrznymi parametrami
    gitversion_configure_file("${VERSION_H_TEMPLATE}" "${VERSION_H}")
else()
    # Nazwy plików oparte na prefixie, np. TEVersion.h
    set(_VERSION_H_FILENAME "${VERSION_PREFIX}Version.h")
    set(_VERSION_H_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/${_VERSION_H_FILENAME}.in")
    set(_VERSION_H         "${VERSION_OUT_DIR}/${_VERSION_H_FILENAME}")

    message(CHECK_START "Find '${_VERSION_H_FILENAME}.in'")
    if(NOT EXISTS "${_VERSION_H_TEMPLATE}")
        set(_VERSION_H_TEMPLATE "${VERSION_OUT_DIR}/${_VERSION_H_FILENAME}.in")
        message(CHECK_FAIL "Not Found. Generating '${_VERSION_H_TEMPLATE}'")

        file(WRITE "${_VERSION_H_TEMPLATE}"
[=[
#define @_VERSION_PREFIX@VERSION_MAJOR @_VERSION_MAJOR@
#define @_VERSION_PREFIX@VERSION_MINOR @_VERSION_MINOR@
#define @_VERSION_PREFIX@VERSION_PATCH @_VERSION_PATCH@
#define @_VERSION_PREFIX@VERSION_COMMIT @_VERSION_COMMIT@
#define @_VERSION_PREFIX@VERSION_SHA "@_VERSION_SHA@"
#define @_VERSION_PREFIX@VERSION_SEMANTIC "@_VERSION_SEMANTIC@"
#define @_VERSION_PREFIX@VERSION_FULL "@_VERSION_FULL@"
]=])
        if(NOT EXISTS "${_VERSION_H_TEMPLATE}")
            message(FATAL_ERROR "Failed to create template ${_VERSION_H_TEMPLATE}")
        endif()
    else()
        message(CHECK_PASS "Found '${_VERSION_H_TEMPLATE}'")
    endif()

    # Target generujący nagłówek
	add_custom_target(${_VERSION_TARGET_GEN}
		ALL
		BYPRODUCTS "${_VERSION_H}"
		SOURCES    "${_VERSION_H_TEMPLATE}"
		DEPENDS    "${_GIT_CACHE_PATH}/index"
				   "${_GIT_CACHE_PATH}/HEAD"
		COMMENT "Version.cmake: Generating `${_VERSION_H_FILENAME}` (prefix '${VERSION_PREFIX}')"
		COMMAND ${CMAKE_COMMAND}
			-B "${VERSION_OUT_DIR}"
			-DVERSION_GENERATE_NOW:BOOL=ON
			-DVERSION_H_TEMPLATE:PATH=${_VERSION_H_TEMPLATE}
			-DVERSION_H:PATH=${_VERSION_H}
			-DVERSION_PREFIX:STRING=${VERSION_PREFIX}
			-DGIT_EXECUTABLE:FILEPATH=${GIT_EXECUTABLE}
			-DCMAKE_MODULE_PATH:PATH=${CMAKE_MODULE_PATH}
			-P "${CMAKE_CURRENT_LIST_FILE}"
		WORKING_DIRECTORY "${VERSION_SOURCE_DIR}"
		VERBATIM
	)

    add_library(${_VERSION_TARGET_IFACE} INTERFACE)
    target_include_directories(${_VERSION_TARGET_IFACE} INTERFACE
        $<BUILD_INTERFACE:${VERSION_OUT_DIR}>
        $<INSTALL_INTERFACE:include>
    )

    if(POLICY CMP0115)
        cmake_policy(SET CMP0115 NEW)
    endif()

    set_target_properties(${_VERSION_TARGET_IFACE} PROPERTIES
        PUBLIC_HEADER "${_VERSION_H}"
    )
    add_dependencies(${_VERSION_TARGET_IFACE}
        INTERFACE ${_VERSION_TARGET_GEN}
    )

    add_library(${_VERSION_ALIAS} ALIAS ${_VERSION_TARGET_IFACE})
endif()

list(POP_BACK CMAKE_MESSAGE_INDENT)

# ---------- Log końcowy ----------

if(VERSION_GENERATE_NOW)
    set(_VERSION_H_GENERATED TRUE)
else()
    get_source_file_property(_VERSION_H_GENERATED "${_VERSION_H}" GENERATED)
endif()

if(NOT _VERSION_NOT_GIT_REPO)
    if(NOT _VERSION_SET)
        message(CHECK_FAIL "Version.cmake failed - VERSION_SET==false")
    elseif(_VERSION_H_GENERATED)
        message(CHECK_PASS "${_VERSION_FULL} [${_VERSION_SEMANTIC}] {Generated}")
    elseif(EXISTS "${_VERSION_H}")
        message(CHECK_PASS "Using pre-defined '${_VERSION_H}'")
    else()
        message(CHECK_FAIL "Failed, ${_VERSION_H} not available")
    endif()
else()
    message(CHECK_FAIL "Failed, Error reading Git repository")
endif()
