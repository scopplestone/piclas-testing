# =========================================================================
# Git configuration
# =========================================================================
# Find the path to the .git directory
EXECUTE_PROCESS(COMMAND git rev-parse --git-dir WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} OUTPUT_VARIABLE GIT_DIR OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE GIT_COMMON_ERR)
IF(NOT GIT_COMMON_ERR EQUAL 0)
  MESSAGE(FATAL_ERROR "Could not determine .git directory (git rev-parse --git-dir failed)")
ENDIF()
# resolve symlinks
GET_FILENAME_COMPONENT(GIT_DIR "${GIT_DIR}" REALPATH)
MESSAGE(STATUS "Resolved .git directory: ${GIT_DIR}")

# Check where the code originates
IF(EXISTS ${GIT_DIR})
  EXECUTE_PROCESS(COMMAND git ls-remote --get-url WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} OUTPUT_VARIABLE GIT_ORIGIN OUTPUT_STRIP_TRAILING_WHITESPACE)
  MESSAGE(STATUS "Checking git origin: " ${GIT_ORIGIN})

  # Setup git hooks
  SET(PRECOMMIT_FILE ".githooks/pre-commit")
ENDIF()

# Perform checks only if origin points to boltzplatz.eu, other origins can't commit
IF("${GIT_ORIGIN}" MATCHES "piclas.boltzplatz.eu")
  # Check if the pre-commit hooks exits
  IF (NOT EXISTS ${GIT_DIR}/.git/hooks/pre-commit)
    # Create otherwise
    FILE(MAKE_DIRECTORY ${GIT_DIR}/.git/hooks)
    EXECUTE_PROCESS(COMMAND ln -s ${CMAKE_CURRENT_SOURCE_DIR}/${PRECOMMIT_FILE} ${GIT_DIR}/.git/hooks/pre-commit)
  ELSE()
    # Check if the hook is the correct symlink and warn otherwise
    EXECUTE_PROCESS(COMMAND readlink ${GIT_DIR}/.git/hooks/pre-commit OUTPUT_VARIABLE PRECOMMIT_LINK OUTPUT_STRIP_TRAILING_WHITESPACE)
    IF (NOT ${PRECOMMIT_LINK} MATCHES "${CMAKE_CURRENT_SOURCE_DIR}/${PRECOMMIT_FILE}")
      MESSAGE (WARNING "Custom git pre-commit hook detected. Please ensure to call ${PRECOMMIT_FILE} manually.")
    ENDIF()
  ENDIF()

  # Check if the hook actually gets loaded
  EXECUTE_PROCESS(COMMAND git config --get core.hooksPath OUTPUT_VARIABLE HOOKSPATH OUTPUT_STRIP_TRAILING_WHITESPACE WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
  IF (DEFINED HOOKSPATH  AND NOT "${HOOKSPATH}" STREQUAL "" AND NOT "${HOOKSPATH}" STREQUAL ".git/hooks")
    # STRING(ASCII 27 ESCAPE)
    # MESSAGE (STATUS "${ESCAPE}[34mCustom hooks path detected. Please ensure to call ${PRECOMMIT_FILE} manually.${ESCAPE}[0m")
    MESSAGE (WARNING "Custom git hooks path detected. Please ensure to call ${PRECOMMIT_FILE} manually.")
  ENDIF()
ENDIF()