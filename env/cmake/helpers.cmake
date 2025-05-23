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
