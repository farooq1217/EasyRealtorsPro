// Re-export the main web stub for features
import '../../web_stub.dart' as io;

// Re-export all the classes including exceptions
export '../../web_stub.dart' show 
  Platform, 
  Directory, 
  File, 
  FileSystemEntity, 
  Uint8List, 
  PathNotFoundException, 
  FileSystemException, 
  PathAccessException, 
  FileMode;
