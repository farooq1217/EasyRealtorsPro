#include "flutter/dart_project.h"
#include "flutter/flutter_view_controller.h"
#include "flutter_window.h"
#include "utils.h"
// auto_updater plugin is registered via generated_plugin_registrant; manual include removed.
#include <windows.h>

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Existing setup code (e.g., console attachment) can be placed here if needed.

  // Retrieve command line arguments for Dart entrypoint.
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  // Auto updater registration handled by generated_plugin_registrant.

  // Initialize the Dart project.
  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Create the Flutter window.
  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"EasyRealtorsPro", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Initialize COM for any plugins that require it.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Main message loop.
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
