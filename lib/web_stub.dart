// Web stub for sqlite3 to prevent FFI compilation errors
// This file provides empty implementations for web builds

import 'dart:async';

class WebDatabaseStub {
  WebDatabaseStub(String name);
  
  Future<void> close() async {}
}

// Web stub for NativeDatabase
class NativeDatabase {
  NativeDatabase.memory() {
    throw Exception('NativeDatabase not supported on web');
  }
  
  NativeDatabase(String path, {bool logStatements = false}) {
    throw Exception('NativeDatabase not supported on web');
  }
}

// Web stub for sqlite3 package
class Sqlite3Stub {
  static const sqlite3 = null;
}

const sqlite3 = Sqlite3Stub.sqlite3;

// Web stub for dart:io
class Platform {
  static const bool isWindows = false;
  static const bool isLinux = false;
  static const bool isMacOS = false;
  static const bool isAndroid = false;
  static const bool isIOS = false;
  static const bool isFuchsia = false;
}

class Directory {
  Directory(String path);
  
  String get path => '/tmp';
  
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
}

class FileSystemEntity {
  static String join(String part1, String part2) => '$part1/$part2';
}

// Web stub for path_provider functions
Future<Directory> getApplicationSupportDirectory() async {
  return Directory('/tmp');
}

// Web stub for path_provider functions
Future<Directory> getApplicationDocumentsDirectory() async {
  return Directory('/tmp');
}

// Web stub for path_provider functions
Future<Directory> getTemporaryDirectory() async {
  return Directory('/tmp');
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

// Web stub for exceptions
class PathNotFoundException implements Exception {
  final String message;
  PathNotFoundException(this.message);
}

class FileSystemException implements Exception {
  final String message;
  final String path;
  FileSystemException(this.message, this.path);
}

class PathAccessException implements Exception {
  final String message;
  PathAccessException(this.message);
}


// Web stub for drift/native.dart  
class NativeDatabaseStub {
  static dynamic fromExecutor(dynamic executor) => throw UnsupportedError('NativeDatabase not supported on web');
  static dynamic inMemory() => throw UnsupportedError('NativeDatabase not supported on web');
}
