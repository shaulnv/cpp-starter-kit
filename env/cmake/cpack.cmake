# CPack configuration: DEB/RPM packages plus a separate debug-symbols package.
#
# Include from the top-level CMakeLists.txt after all install() rules. Needs set_project_version() (version.cmake) to
# have run for the production/nightly flags.
#
# Package version schemes (all sort correctly in dpkg and rpm): production  X.Y.Z nightly
# X.Y.Z-YYYY.MM.DD.<commit-count>.<sha> dev         X.Y.Z~<prio>.<pr|branch>.<branch>.git<date>.<sha>   ('~' sorts below
# X.Y.Z)

function(set_cpack_generator_by_os)
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    if(EXISTS "/etc/debian_version")
      set(CPACK_GENERATOR
          "DEB"
          PARENT_SCOPE)
    elseif(EXISTS "/etc/redhat-release" OR EXISTS "/etc/amazon-linux-release")
      set(CPACK_GENERATOR
          "RPM"
          PARENT_SCOPE)
    else()
      set(CPACK_GENERATOR
          "DEB;RPM"
          PARENT_SCOPE)
    endif()
  else()
    set(CPACK_GENERATOR
        "DEB;RPM"
        PARENT_SCOPE)
  endif()
endfunction()

function(configure_git_versioning)
  find_package(Git QUIET)
  if(NOT GIT_FOUND)
    set(IS_GIT_BUILD
        FALSE
        PARENT_SCOPE)
    message(STATUS "Git not found, using default package versioning.")
    return()
  endif()

  execute_process(
    COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_SHORT_HASH
    OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
  execute_process(
    COMMAND ${GIT_EXECUTABLE} log -1 --format=%cd --date=format:%Y%m%d%H%M
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_DATE
    OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
  # Monotonic across history, so two nightlies on the same day still order. Only meaningful on a full clone (CI must
  # unshallow first).
  execute_process(
    COMMAND ${GIT_EXECUTABLE} rev-list --count HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_COUNT
    OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
  if(NOT GIT_COMMIT_COUNT)
    set(GIT_COMMIT_COUNT "0")
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} symbolic-ref --short HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_BRANCH
    OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)

  if(NOT GIT_SHORT_HASH OR NOT GIT_COMMIT_DATE)
    set(IS_GIT_BUILD
        FALSE
        PARENT_SCOPE)
    message(STATUS "Not a Git-based build, using default package versioning.")
    return()
  endif()

  # CI exports CI_PULL_REQUEST_NUMBER for PR builds (e.g. github.event.pull_request.number).
  if(NOT "$ENV{CI_PULL_REQUEST_NUMBER}" STREQUAL "")
    set(_category "pr$ENV{CI_PULL_REQUEST_NUMBER}")
  else()
    set(_category "branch")
  endif()

  # A master package outranks a feature-branch package of the same version.
  set(_priority "0")
  if(GIT_BRANCH STREQUAL "master" OR GIT_BRANCH STREQUAL "main")
    set(_priority "1")
  endif()

  set(_id_deb "${_priority}.${_category}")
  set(_id_rpm "${_priority}.${_category}")
  # Empty on a detached HEAD. DEB allows '-' but not '/'; RPM release allows neither.
  if(NOT GIT_BRANCH STREQUAL "")
    string(REPLACE "/" "." _branch_deb "${GIT_BRANCH}")
    string(REPLACE "/" "." _branch_rpm "${GIT_BRANCH}")
    string(REPLACE "-" "_" _branch_rpm "${_branch_rpm}")
    string(APPEND _id_deb ".${_branch_deb}")
    string(APPEND _id_rpm ".${_branch_rpm}")
  endif()

  set(IS_GIT_BUILD
      TRUE
      PARENT_SCOPE)
  set(GIT_COMMIT_DATE
      ${GIT_COMMIT_DATE}
      PARENT_SCOPE)
  set(GIT_SHORT_HASH
      ${GIT_SHORT_HASH}
      PARENT_SCOPE)
  set(GIT_COMMIT_COUNT
      ${GIT_COMMIT_COUNT}
      PARENT_SCOPE)
  set(GIT_BUILD_IDENTIFIER_DEB
      ${_id_deb}
      PARENT_SCOPE)
  set(GIT_BUILD_IDENTIFIER_RPM
      ${_id_rpm}
      PARENT_SCOPE)
  message(STATUS "Git-based build: ${_category} ${GIT_COMMIT_DATE}.${GIT_COMMIT_COUNT}-${GIT_SHORT_HASH}")
endfunction()

# RPM distribution tag (el9, amzn2023, fc40) from /etc/os-release.
function(get_dist_tag OUT_VAR)
  set(DIST_TAG "linux")
  if(EXISTS "/etc/os-release")
    file(STRINGS "/etc/os-release" OS_RELEASE_LINES REGEX "^(ID|VERSION_ID)=")
    foreach(LINE ${OS_RELEASE_LINES})
      if(LINE MATCHES "^ID=(.*)")
        string(REPLACE "\"" "" DIST_ID ${CMAKE_MATCH_1})
      elseif(LINE MATCHES "^VERSION_ID=\"?([0-9]+)")
        set(DIST_VERSION_MAJOR ${CMAKE_MATCH_1})
      endif()
    endforeach()

    if(DIST_ID MATCHES "rhel|centos|rocky|almalinux")
      set(DIST_TAG "el${DIST_VERSION_MAJOR}")
    elseif(DIST_ID MATCHES "amzn")
      set(DIST_TAG "amzn${DIST_VERSION_MAJOR}")
    elseif(DIST_ID MATCHES "fedora")
      set(DIST_TAG "fc${DIST_VERSION_MAJOR}")
    endif()
  endif()
  set(${OUT_VAR}
      ${DIST_TAG}
      PARENT_SCOPE)
endfunction()

function(get_package_architecture DEB_VAR RPM_VAR)
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
    set(_deb "amd64")
    set(_rpm "x86_64")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    set(_deb "arm64")
    set(_rpm "aarch64")
  else()
    set(_deb "all")
    set(_rpm "noarch")
    message(
      WARNING "Unknown CMAKE_SYSTEM_PROCESSOR '${CMAKE_SYSTEM_PROCESSOR}', packaging as architecture-independent.")
  endif()
  set(${DEB_VAR}
      ${_deb}
      PARENT_SCOPE)
  set(${RPM_VAR}
      ${_rpm}
      PARENT_SCOPE)
endfunction()

# Distro codename (jammy, bookworm) is part of the DEB file name so packages built for several distros can share dist/.
function(get_debian_codename OUT_VAR)
  set(CODENAME "unstable")
  if(EXISTS "/etc/os-release")
    file(STRINGS "/etc/os-release" OS_RELEASE_LINES REGEX "^VERSION_CODENAME=")
    if(OS_RELEASE_LINES)
      string(REPLACE "VERSION_CODENAME=" "" CODENAME "${OS_RELEASE_LINES}")
    endif()
  endif()
  set(${OUT_VAR}
      ${CODENAME}
      PARENT_SCOPE)
endfunction()

function(generate_changelog_from_git OUT_VAR)
  find_package(Git QUIET)
  if(NOT GIT_FOUND)
    return()
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} log -n 20 "--pretty=format:  * %s (%h)"
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_LOG_ENTRIES
    ERROR_QUIET)
  string(STRIP "${GIT_LOG_ENTRIES}" GIT_LOG_ENTRIES)
  set(${OUT_VAR}
      "${GIT_LOG_ENTRIES}"
      PARENT_SCOPE)
endfunction()

set_cpack_generator_by_os()
get_debian_codename(DEBIAN_CODENAME)
get_package_architecture(CPACK_DEBIAN_PACKAGE_ARCHITECTURE CPACK_RPM_PACKAGE_ARCHITECTURE)

set(CPACK_PACKAGE_DIRECTORY ${CMAKE_SOURCE_DIR}/dist)
set(CPACK_PACKAGE_NAME "starterkit")
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_DESCRIPTION "${PROJECT_DESCRIPTION}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
set(CPACK_PACKAGE_HOMEPAGE_URL ${PROJECT_HOMEPAGE_URL})
set(CPACK_PACKAGE_VENDOR "starterkit")
set(CPACK_PACKAGE_CONTACT "starterkit maintainers")
# Installs under a private prefix so the package never collides with distro files.
set(CPACK_PACKAGING_INSTALL_PREFIX
    "/usr/local/${CPACK_PACKAGE_NAME}"
    CACHE PATH "Installation prefix for CPack packages")

set(CPACK_DEBIAN_PACKAGE_SECTION "devel")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")

set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_RPM_PACKAGE_GROUP "Applications/System")
# Drops the /usr/lib/.build-id/* links, which collide between packages built by the same toolchain.
set(CPACK_RPM_SPEC_MORE_DEFINE "%define _build_id_links none")

configure_git_versioning()
set(CPACK_RPM_PACKAGE_RELEASE "1")
if(IS_GIT_BUILD)
  # Dev: '~' marks it a pre-release of the final X.Y.Z, so apt/dnf prefer the real release.
  set(_dev_version_deb "${CPACK_PACKAGE_VERSION}~${GIT_BUILD_IDENTIFIER_DEB}.git${GIT_COMMIT_DATE}.${GIT_SHORT_HASH}")
  set(_dev_release_rpm "0.${GIT_BUILD_IDENTIFIER_RPM}.git${GIT_COMMIT_DATE}.${GIT_SHORT_HASH}")

  if(STARTERKIT_IS_PRODUCTION_VERSION)
    set(CPACK_DEBIAN_PACKAGE_VERSION "${CPACK_PACKAGE_VERSION}")
    set(CPACK_RPM_PACKAGE_RELEASE "1")
  elseif(STARTERKIT_IS_NIGHTLY_VERSION)
    # GIT_COMMIT_DATE is %Y%m%d%H%M. dpkg and rpm both compare '.'-separated numeric runs numerically, so date + commit
    # count dominate the ordering and the sha only breaks ties.
    string(SUBSTRING "${GIT_COMMIT_DATE}" 0 4 _year)
    string(SUBSTRING "${GIT_COMMIT_DATE}" 4 2 _month)
    string(SUBSTRING "${GIT_COMMIT_DATE}" 6 2 _day)
    set(_nightly "${_year}.${_month}.${_day}.${GIT_COMMIT_COUNT}.${GIT_SHORT_HASH}")
    set(CPACK_DEBIAN_PACKAGE_VERSION "${CPACK_PACKAGE_VERSION}-${_nightly}")
    set(CPACK_RPM_PACKAGE_RELEASE "${_nightly}")
  else()
    set(CPACK_DEBIAN_PACKAGE_VERSION "${_dev_version_deb}")
    set(CPACK_RPM_PACKAGE_RELEASE "${_dev_release_rpm}")
  endif()
else()
  set(CPACK_DEBIAN_PACKAGE_VERSION "${CPACK_PACKAGE_VERSION}")
endif()

# DEB: name_version_codename_arch.deb
set(CPACK_DEBIAN_FILE_NAME
    "${CPACK_PACKAGE_NAME}_${CPACK_DEBIAN_PACKAGE_VERSION}_${DEBIAN_CODENAME}_${CPACK_DEBIAN_PACKAGE_ARCHITECTURE}.deb")

# The automatic %{?dist} suffix depends on the build host's rpm macros; spell it out so the file name is deterministic
# (name-version-release.dist.arch.rpm).
get_dist_tag(DIST_TAG)
set(CPACK_RPM_PACKAGE_RELEASE_DIST ON)
set(CPACK_RPM_PACKAGE_DISTRIBUTION ${DIST_TAG})
set(CPACK_RPM_FILE_NAME
    "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${CPACK_RPM_PACKAGE_RELEASE}.${DIST_TAG}.${CPACK_RPM_PACKAGE_ARCHITECTURE}.rpm"
)
# Exposed through the cache so CI can read the exact version with `cmake -L -N`.
set(STARTERKIT_DEB_PACKAGE_VERSION_FULL
    "${CPACK_DEBIAN_PACKAGE_VERSION}"
    CACHE STRING "Full DEB package version" FORCE)
set(STARTERKIT_RPM_PACKAGE_VERSION_FULL
    "${CPACK_PACKAGE_VERSION}-${CPACK_RPM_PACKAGE_RELEASE}.${DIST_TAG}"
    CACHE STRING "Full RPM package version" FORCE)

if(CPACK_GENERATOR STREQUAL "RPM")
  set(STARTERKIT_OS_PACKAGE_NAME "${CPACK_RPM_FILE_NAME}")
else()
  set(STARTERKIT_OS_PACKAGE_NAME "${CPACK_DEBIAN_FILE_NAME}")
endif()
message(STATUS "OS package: ${STARTERKIT_OS_PACKAGE_NAME}")

# Changelog from git history. DEB gets it installed explicitly (more robust than CPACK_DEBIAN_CHANGELOG); RPM reads it
# via CPACK_RPM_CHANGELOG_FILE.
generate_changelog_from_git(CHANGELOG_ENTRIES)
execute_process(
  COMMAND date -R
  OUTPUT_VARIABLE CURRENT_DATE
  OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
set(CHANGELOG_FILE "${CMAKE_CURRENT_BINARY_DIR}/changelog.Debian")
file(
  WRITE ${CHANGELOG_FILE}
  "${CPACK_PACKAGE_NAME} (${CPACK_DEBIAN_PACKAGE_VERSION}) ${DEBIAN_CODENAME}; urgency=medium\n\n${CHANGELOG_ENTRIES}\n\n -- ${CPACK_PACKAGE_CONTACT}  ${CURRENT_DATE}"
)
install(
  FILES ${CHANGELOG_FILE}
  DESTINATION share/doc/${CPACK_PACKAGE_NAME}
  RENAME changelog.Debian)
set(CPACK_RPM_CHANGELOG_FILE ${CHANGELOG_FILE})

# Debug symbols ship as a separate package that depends on the main one. Needs a build with debug info (RelWithDebInfo /
# Debug); a Release build leaves nothing to split out.
set(CPACK_DEBUGINFO_PACKAGE ON)
set(CPACK_DEBIAN_DEBUGINFO_PACKAGE ON)
set(CPACK_DEBIAN_DEBUGINFO_PACKAGE_NAME "${CPACK_PACKAGE_NAME}-dbgsym")
set(CPACK_DEBIAN_DEBUGINFO_PACKAGE_DEPENDS "${CPACK_PACKAGE_NAME}")
set(CPACK_RPM_DEBUGINFO_PACKAGE ON)
set(CPACK_RPM_DEBUGINFO_PACKAGE_NAME "${CPACK_PACKAGE_NAME}-debuginfo")
set(CPACK_RPM_DEBUGINFO_PACKAGE_REQUIRES "${CPACK_PACKAGE_NAME}")
# Where gdb on the debugged host finds the sources.
set(CPACK_RPM_BUILD_SOURCE_DIRS_PREFIX "/usr/src/debug/${CPACK_PACKAGE_NAME}")

include(CPack)
