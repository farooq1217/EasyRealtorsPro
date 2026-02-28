import 'dart:typed_data';

class Platform {
  static String get pathSeparator => '/';
  static String get operatingSystem => 'web';
  static String get operatingSystemVersion => '';
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isAndroid => false;
  static bool get isIOS => false;
}

class File {
  final String path;
  File(this.path);

  Future<bool> exists() async => false;

  Future<String> readAsString() {
    throw UnsupportedError('File I/O is not supported on web');
  }

  Future<void> writeAsString(String _) {
    throw UnsupportedError('File I/O is not supported on web');
  }

  Future<Uint8List> readAsBytes() {
    throw UnsupportedError('File I/O is not supported on web');
  }

  Future<File> writeAsBytes(List<int> _, {bool flush = false}) {
    throw UnsupportedError('File I/O is not supported on web');
  }

  Future<File> create({bool recursive = false}) async => this;

  bool existsSync() => false;

  void deleteSync() {
    throw UnsupportedError('File I/O is not supported on web');
  }

  Future<void> delete() {
    throw UnsupportedError('File I/O is not supported on web');
  }
}

class Directory {
  final String path;
  Directory(this.path);

  static Directory get current => Directory('/');

  Future<bool> exists() async => false;

  Future<Directory> create({bool recursive = false}) {
    throw UnsupportedError('Directory I/O is not supported on web');
  }

  Future<Directory> createTemp(String prefix) async {
    return Directory('/tmp/${prefix}_${DateTime.now().millisecondsSinceEpoch}');
  }
}
