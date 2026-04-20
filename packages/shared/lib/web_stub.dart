// Web stub for shared package - provides web-compatible implementations
import 'dart:async';
import 'dart:typed_data';

class Directory {
  final String path;
  Directory(this.path);
  
  Future<bool> exists() async => false;
  Future<void> create({bool recursive = false}) async {}
  Stream<FileSystemEntity> list() async* {}
}

class File {
  File(String path);
  
  String get path => '/tmp';
  Directory get parent => Directory('/tmp');
  
  Future<bool> exists() async => false;
  Future<void> writeAsBytes(List<int> bytes) async {}
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Future<void> copy(String newPath) async {}
  Future<void> writeAsString(String content, {FileMode mode = FileMode.write, bool flush = false}) async {}
  Future<void> delete() async {}
}

class FileSystemEntity {
  static String join(String part1, String part2) => '$part1/$part2';
}

class FileMode {
  static const write = FileMode('write');
  final String value;
  const FileMode(this.value);
}

class Uint8List {
  Uint8List(int length);
  Uint8List.fromList(List<int> list);
}

// Web stub for path_provider functions
Future<Directory> getApplicationSupportDirectory() async {
  return Directory('/tmp');
}

Future<Directory> getApplicationDocumentsDirectory() async {
  return Directory('/tmp');
}

Future<Directory> getTemporaryDirectory() async {
  return Directory('/tmp');
}
