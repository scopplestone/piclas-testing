# =========================================================================
# Git configuration
# =========================================================================
# Determine whether the source tree itself is the root of a git repository. Checking
# `git rev-parse` alone is not enough: git searches parent directories, so a manually
# downloaded source tree (e.g. an archive without a .git directory) placed inside another
# git repository would otherwise pick up that outer .git. Compare the repository top-level
# against the source dir and skip the git hook setup unless they match.
EXECUTE_PROCESS(COMMAND git rev-parse --show-toplevel WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} OUTPUT_VARIABLE GIT_TOPLEVEL OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE GIT_COMMON_ERR ERROR_QUIET)
GET_FILENAME_COMPONENT(GIT_TOPLEVEL "${GIT_TOPLEVEL}" REALPATH)
GET_FILENAME_COMPONENT(SOURCE_REALPATH "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
IF(NOT GIT_COMMON_ERR EQUAL 0 OR NOT "${GIT_TOPLEVEL}" STREQUAL "${SOURCE_REALPATH}")
  MESSAGE(STATUS "Not a git repository, skipping git hook setup")
ELSE()
  # Find the common .git directory. Using --git-common-dir (instead of --git-dir) ensures
  # the hooks are installed where git actually runs them, also for linked worktrees where
  # the per-worktree git dir differs from the shared one. It may be returned as a relative
  # path (in a regular checkout), so resolve it against the source dir.
  EXECUTE_PROCESS(COMMAND git rev-parse --git-common-dir WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} OUTPUT_VARIABLE GIT_DIR OUTPUT_STRIP_TRAILING_WHITESPACE)
  GET_FILENAME_COMPONENT(GIT_DIR "${GIT_DIR}" REALPATH BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  MESSAGE(STATUS "Resolved .git directory: ${GIT_DIR}")

  # Check where the code originates
  EXECUTE_PROCESS(COMMAND git ls-remote --get-url WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} OUTPUT_VARIABLE GIT_ORIGIN OUTPUT_STRIP_TRAILING_WHITESPACE)
  MESSAGE(STATUS "Checking git origin: " ${GIT_ORIGIN})

  # Setup git hooks
  SET(PRECOMMIT_FILE ".githooks/pre-commit")

  # Perform checks only if origin points to boltzplatz.eu, other origins can't commit
  IF("${GIT_ORIGIN}" MATCHES "piclas.boltzplatz.eu")
    # Check if the pre-commit hooks exits
    IF (NOT EXISTS ${GIT_DIR}/hooks/pre-commit)
      # Create otherwise
      FILE(MAKE_DIRECTORY ${GIT_DIR}/hooks)
      EXECUTE_PROCESS(COMMAND ln -s ${CMAKE_CURRENT_SOURCE_DIR}/${PRECOMMIT_FILE} ${GIT_DIR}/hooks/pre-commit)
    ELSE()
      # Check if the hook is the correct symlink and warn otherwise
      EXECUTE_PROCESS(COMMAND readlink ${GIT_DIR}/hooks/pre-commit OUTPUT_VARIABLE PRECOMMIT_LINK OUTPUT_STRIP_TRAILING_WHITESPACE)
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
ENDIF()
