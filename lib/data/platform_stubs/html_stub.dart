// Fallback stubs so conditional imports that target `dart:html` compile on
// mobile/desktop builds. These no-op implementations are never executed
// outside the web runtime.
class Blob {
  final List<dynamic> _data;
  final String? type;
  Blob(this._data, [this.type]);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String? href;
  String? target;
  String? download;

  AnchorElement({this.href});

  void click() {}

  void setAttribute(String name, String value) {}

  void remove() {}
}

class BodyElement {
  void append(dynamic _) {}
}

class Window {
  void open(String url, String name) {}
}

final document = _DocumentStub();
final window = Window();

class _DocumentStub {
  BodyElement? body = BodyElement();
}
