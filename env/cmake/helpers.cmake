include(${CMAKE_CURRENT_LIST_DIR}/ColorFormatting.cmake)

# Define a function to add a post-build copy command for a target
function(add_post_build_copy target source_file destination_file)
  add_custom_command(
    TARGET ${target}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${source_file}" "${destination_file}" > /dev/null 2>&1 || true
    COMMENT "Copying ${source_file} to ${destination_file} after building ${target}")
endfunction()

function(notice_message message)
  # Formatted text is saved in COLOR_FORMATTED_TEXT
  colorformattext(BOLD COLOR CYAN "NOTICE:")
  # Print the formatted text and append unformatted text
  message(STATUS "${COLOR_FORMATTED_TEXT} ${message}")
endfunction()

# Sets OUT_VAR to TRUE when running on Linux with a kernel >= REQUIRED_VERSION (e.g. "5.10").
function(linux_kernel_at_least REQUIRED_VERSION OUT_VAR)
  set(${OUT_VAR}
      FALSE
      PARENT_SCOPE)
  if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
    return()
  endif()

  execute_process(
    COMMAND uname -r
    OUTPUT_VARIABLE kernel_version
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE uname_result)
  if(NOT uname_result EQUAL 0)
    return()
  endif()

  # 5.10.0-23-amd64 -> 5.10.0
  string(REGEX MATCH "^[0-9]+\\.[0-9]+(\\.[0-9]+)?" kernel_version_numeric "${kernel_version}")
  if(kernel_version_numeric VERSION_GREATER_EQUAL REQUIRED_VERSION)
    set(${OUT_VAR}
        TRUE
        PARENT_SCOPE)
  endif()
endfunction()
