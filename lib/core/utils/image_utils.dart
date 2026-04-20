import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:image/image.dart' as img_pkg;
import 'dart:typed_data';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'platform_utils.dart';

/// Universal image handling for cross-platform compatibility
class ImageUtils {
  /// Picks image from camera or gallery based on platform
  static Future<ImageResult?> pickImage(ImageSource source) async {
    try {
      if (kIsWeb) {
        return await _pickImageWeb(source);
      } else if (PlatformUtils.usesFileSelector) {
        return await _pickImageDesktop(source);
      } else {
        return await _pickImageMobile(source);
      }
    } catch (e) {
      debugPrint('ImageUtils: Failed to pick image: $e');
      return null;
    }
  }

  /// Picks image on web platform
  static Future<ImageResult?> _pickImageWeb(ImageSource source) async {
    final picker = ImagePicker();
    
    XFile? pickedFile;
    if (source == ImageSource.camera) {
      pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
    } else {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
    }
    
    if (pickedFile == null) return null;
    
    // On web, read bytes directly
    final bytes = await pickedFile.readAsBytes();
    return ImageResult(
      bytes: bytes,
      path: pickedFile.name, // Use filename instead of path
      size: bytes.length,
      platform: 'web',
    );
  }

  /// Picks image on desktop platforms
  static Future<ImageResult?> _pickImageDesktop(ImageSource source) async {
    if (source == ImageSource.camera) {
      // Desktop camera support through file_selector
      final result = await file_selector.openFile(
        acceptedTypeGroups: [
          const file_selector.XTypeGroup(
            label: 'Images',
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
          ),
        ],
      );
      
      if (result == null) return null;
      
      final bytes = await result.readAsBytes();
      return ImageResult(
        bytes: bytes,
        path: result.path,
        size: bytes.length,
        platform: 'desktop',
      );
    } else {
      // Gallery on desktop
      final result = await file_selector.openFile(
        acceptedTypeGroups: [
          const file_selector.XTypeGroup(
            label: 'Images',
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
          ),
        ],
      );
      
      if (result == null) return null;
      
      final bytes = await result.readAsBytes();
      return ImageResult(
        bytes: bytes,
        path: result.path,
        size: bytes.length,
        platform: 'desktop',
      );
    }
  }

  /// Picks image on mobile platforms
  static Future<ImageResult?> _pickImageMobile(ImageSource source) async {
    final picker = ImagePicker();
    
    XFile? pickedFile;
    if (source == ImageSource.camera) {
      pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
    } else {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
    }
    
    if (pickedFile == null) return null;
    
    // On mobile, verify file exists
    final file = io.File(pickedFile.path);
    if (!await file.exists()) return null;
    
    final bytes = await file.readAsBytes();
    return ImageResult(
      bytes: bytes,
      path: pickedFile.path,
      size: bytes.length,
      platform: 'mobile',
    );
  }

  /// Compresses image to target size
  static Future<ImageResult?> compressImage(
    ImageResult image, {
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
    int maxSizeBytes = 1024 * 1024, // 1MB
  }) async {
    try {
      // Decode image
      final originalImage = img_pkg.decodeImage(image.bytes);
      if (originalImage == null) return null;
      
      // Calculate new dimensions
      int newWidth = originalImage.width;
      int newHeight = originalImage.height;
      
      if (originalImage.width > maxWidth || originalImage.height > maxHeight) {
        final aspectRatio = originalImage.width / originalImage.height;
        if (originalImage.width > originalImage.height) {
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        } else {
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
      }
      
      // Resize image
      final resizedImage = img_pkg.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img_pkg.Interpolation.average,
      );
      
      // Compress with quality adjustment
      Uint8List compressedBytes;
      int currentQuality = quality;
      
      do {
        compressedBytes = Uint8List.fromList(
          img_pkg.encodeJpg(resizedImage, quality: currentQuality),
        );
        
        if (compressedBytes.length <= maxSizeBytes || currentQuality <= 10) {
          break;
        }
        
        currentQuality -= 10;
      } while (currentQuality > 10);
      
      // Generate new path for mobile/desktop
      String? newPath;
      if (!kIsWeb) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = p.extension(image.path);
        newPath = '${p.dirname(image.path)}/compressed_$timestamp$extension';
      }
      
      return ImageResult(
        bytes: compressedBytes,
        path: newPath ?? image.path,
        size: compressedBytes.length,
        platform: image.platform,
        originalSize: image.size,
        compressed: true,
      );
    } catch (e) {
      debugPrint('ImageUtils: Failed to compress image: $e');
      return null;
    }
  }

  /// Saves image to platform-specific storage
  static Future<String?> saveImage(
    Uint8List bytes,
    String module,
    String recordId, {
    String? fileName,
  }) async {
    try {
      if (kIsWeb) {
        // For web, return a placeholder path
        // Actual storage would be Firebase Storage or IndexedDB
        return 'web_${module}_${recordId}_${fileName ?? DateTime.now().millisecondsSinceEpoch}.jpg';
      }
      
      final imageStoragePath = await PlatformUtils.getImageStoragePath();
      final moduleDir = io.Directory('$imageStoragePath/$module');
      
      if (!await moduleDir.exists()) {
        await moduleDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final finalFileName = fileName ?? '${recordId}_$timestamp.jpg';
      final filePath = '${moduleDir.path}/$finalFileName';
      
      final file = io.File(filePath);
      await file.writeAsBytes(bytes);
      
      return filePath;
    } catch (e) {
      debugPrint('ImageUtils: Failed to save image: $e');
      return null;
    }
  }

  /// Validates image format
  static bool isValidImageFormat(Uint8List bytes) {
    try {
      final image = img_pkg.decodeImage(bytes);
      return image != null;
    } catch (e) {
      return false;
    }
  }

  /// Gets image format from bytes
  static String? getImageFormat(Uint8List bytes) {
    try {
      final image = img_pkg.decodeImage(bytes);
      if (image == null) return null;
      
      // Check format based on bytes
      if (bytes.length >= 3) {
        if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
          return 'JPEG';
        } else if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
          return 'PNG';
        } else if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
          return 'WEBP';
        }
      }
      return 'Unknown';
    } catch (e) {
      return null;
    }
  }
}

/// Result of image picking operation
class ImageResult {
  final Uint8List bytes;
  final String path;
  final int size;
  final String platform;
  final int? originalSize;
  final bool compressed;

  ImageResult({
    required this.bytes,
    required this.path,
    required this.size,
    required this.platform,
    this.originalSize,
    this.compressed = false,
  });

  /// Gets compression ratio
  double? get compressionRatio {
    if (originalSize == null) return null;
    return (size / originalSize!) * 100;
  }

  /// Gets file extension
  String get extension {
    final ext = p.extension(path).toLowerCase();
    return ext.isNotEmpty ? ext : '.jpg';
  }

  /// Gets filename without path
  String get filename {
    return p.basename(path);
  }
}
