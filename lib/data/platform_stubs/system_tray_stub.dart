// Stub implementation for SystemTray on non-desktop platforms
class SystemTray {
  Future<void> initSystemTray({required String title, required String iconPath}) async {}
  Future<void> setToolTip(String tooltip) async {}
  void registerSystemTrayEventHandler(Function(String) handler) {}
}

// AppWindow is typically from window_manager package, but we'll include it here for compatibility
class AppWindow {
  void show() {}
  void hide() {}
  void close() {}
}

const String kSystemTrayEventRightClick = 'rightClick';
const String kSystemTrayEventClick = 'click';

