import 'dart:typed_data';

class Platform {
  static String get pathSeparator => '/';
  static String get operatingSystem => 'web';
  static String get operatingSystemVersion => '';
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
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

  Future<bool> exists() async => false;

  Future<Directory> create({bool recursive = false}) {
    throw UnsupportedError('Directory I/O is not supported on web');
  }
}
