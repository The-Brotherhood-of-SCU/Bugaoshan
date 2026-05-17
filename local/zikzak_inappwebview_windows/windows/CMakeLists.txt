# Stub CMake — Dart-only plugin, no native code to compile.
# The registration function is declared to satisfy the generated registrant.
cmake_minimum_required(VERSION 3.14)
set(PLUGIN_NAME "zikzak_inappwebview_windows_plugin")
add_library(${PLUGIN_NAME} SHARED
  "zikzak_in_app_web_view_windows.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
set(${PLUGIN_NAME}_bundled_libraries
  PARENT_SCOPE)
