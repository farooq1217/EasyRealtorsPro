import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image/image.dart' as img_pkg;
import 'package:http/http.dart' as http;
import 'dart:typed_data';

/// Service for caching and optimizing image loading
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, Future<Uint8List?>> _loadingFutures = {};
  static const int _maxCacheSize = 50 * 1024 * 1024; // 50MB
  static const Duration _cacheExpiry = Duration(hours: 24);
  int _currentCacheSize = 0;

  /// Get cached image or load it
  Future<Uint8List?> getImage(String imagePath, {bool forceReload = false}) async {
    // Check memory cache first
    if (!forceReload && _memoryCache.containsKey(imagePath)) {
      final timestamp = _cacheTimestamps[imagePath];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _memoryCache[imagePath];
      } else {
        // Cache expired, remove it
        _removeFromCache(imagePath);
      }
    }

    // Check if already loading
    if (_loadingFutures.containsKey(imagePath)) {
      return _loadingFutures[imagePath];
    }

    // Load image
    final future = _loadImage(imagePath);
    _loadingFutures[imagePath] = future;
    
    try {
      final bytes = await future;
      if (bytes != null) {
        _addToCache(imagePath, bytes);
      }
      return bytes;
    } finally {
      _loadingFutures.remove(imagePath);
    }
  }

  Future<Uint8List?> _loadImage(String imagePath) async {
    try {
      // If it's a local file path (desktop/mobile)
      if (!kIsWeb) {
        // Check if it's an absolute path or relative path
        if (imagePath.startsWith('/') || imagePath.contains('\\') || imagePath.contains(':')) {
          final file = io.File(imagePath);
          if (await file.exists()) {
            return await file.readAsBytes();
          }
        }
      } else {
        // For web, if it's a URL, try to load it
        if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
          try {
            final response = await http.get(Uri.parse(imagePath));
            if (response.statusCode == 200) {
              return response.bodyBytes;
            }
          } catch (e) {
            debugPrint('Error loading image from URL: $e');
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error loading image: $e');
      return null;
    }
  }

  void _addToCache(String key, Uint8List bytes) {
    final size = bytes.length;
    
    // Check if we need to evict old entries
    while (_currentCacheSize + size > _maxCacheSize && _memoryCache.isNotEmpty) {
      final oldestKey = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _removeFromCache(oldestKey);
    }

    _memoryCache[key] = bytes;
    _cacheTimestamps[key] = DateTime.now();
    _currentCacheSize += size;
  }

  void _removeFromCache(String key) {
    final bytes = _memoryCache.remove(key);
    if (bytes != null) {
      _currentCacheSize -= bytes.length;
    }
    _cacheTimestamps.remove(key);
  }

  /// Clear all cache
  void clearCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _currentCacheSize = 0;
  }

  /// Preload images
  Future<void> preloadImages(List<String> imagePaths) async {
    for (final path in imagePaths) {
      if (!_memoryCache.containsKey(path)) {
        getImage(path);
      }
    }
  }
}

/// Optimized image widget with caching and placeholder
class CachedImageWidget extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;

  const CachedImageWidget({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: ImageCacheService().getImage(imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return errorWidget ?? _buildErrorWidget();
        }

        return Image.memory(
          snapshot.data!,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? _buildErrorWidget(),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: placeholder ??
          Center(
            child: Icon(
              Icons.image,
              size: (width != null && height != null)
                  ? (width! < height! ? width! * 0.5 : height! * 0.5)
                  : 24,
              color: Colors.grey.shade400,
            ),
          ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: errorWidget ??
          Icon(
            Icons.broken_image,
            size: (width != null && height != null)
                ? (width! < height! ? width! * 0.5 : height! * 0.5)
                : 24,
            color: Colors.grey.shade400,
          ),
    );
  }
}
