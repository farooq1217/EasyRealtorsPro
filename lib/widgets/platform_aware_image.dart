import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart';
import 'dart:typed_data';
import '../core/utils/platform_utils.dart';

/// Platform-aware image widget that handles web and native differently
class PlatformAwareImage extends StatelessWidget {
  final String? imagePath;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Widget)? builder;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool useCache;

  const PlatformAwareImage({
    super.key,
    this.imagePath,
    this.imageUrl,
    this.imageBytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.builder,
    this.placeholder,
    this.errorWidget,
    this.useCache = true,
  });

  @override
  Widget build(BuildContext context) {
    // Determine which image source to use
    if (imageBytes != null) {
      return _buildBytesImage(context);
    } else if (imageUrl != null) {
      return _buildNetworkImage(context);
    } else if (imagePath != null && imagePath!.isNotEmpty) {
      return _buildPlatformImage(context);
    } else {
      return _buildPlaceholder();
    }
  }

  /// Build image from bytes (works on all platforms)
  Widget _buildBytesImage(BuildContext context) {
    final image = Image.memory(
      imageBytes!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
    );

    return _wrapWithBuilder(context, image);
  }

  /// Build network image (works on all platforms)
  Widget _buildNetworkImage(BuildContext context) {
    Widget image;
    
    if (useCache && !kIsWeb) {
      image = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
      );
    } else {
      image = Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    return _wrapWithBuilder(context, image);
  }

  /// Build platform-specific image from path
  Widget _buildPlatformImage(BuildContext context) {
    if (kIsWeb) {
      // Web: Check if it's a URL or needs special handling
      if (imagePath!.startsWith('http://') || imagePath!.startsWith('https://')) {
        return _buildNetworkImage(context);
      } else {
        // Web: For local paths, we need to handle differently
        // This could be a base64 string, blob URL, or need server-side serving
        return _buildWebLocalImage();
      }
    } else {
      // Native: Use file-based image
      return _buildFileImage();
    }
  }

  /// Build web local image (handles various web image formats)
  Widget _buildWebLocalImage() {
    // Check if it's a base64 string
    if (imagePath!.startsWith('data:image/')) {
      return _buildBase64Image();
    }
    
    // Check if it's a blob URL
    if (imagePath!.startsWith('blob:')) {
      return Image.network(
        imagePath!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }
    
    // For other web local paths, try network first, then fallback
    return Image.network(
      imagePath!,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        // If network fails, try to treat as base64
        if (imagePath!.length > 100 && imagePath!.contains(',')) {
          try {
            return _buildBase64Image();
          } catch (e) {
            return _buildErrorWidget();
          }
        }
        return _buildErrorWidget();
      },
    );
  }

  /// Build base64 image
  Widget _buildBase64Image() {
    try {
      // Extract base64 data
      final base64String = imagePath!.split(',').last;
      final decodedBytes = base64Decode(base64String);
      
      return Image.memory(
        decodedBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    } catch (e) {
      return _buildErrorWidget();
    }
  }

  /// Build file-based image for native platforms
  Widget _buildFileImage() {
    // File images are not supported on web
    return _buildErrorWidget();
  }

  /// Build placeholder widget
  Widget _buildPlaceholder() {
    if (placeholder != null) {
      return SizedBox(
        width: width,
        height: height,
        child: placeholder,
      );
    }
    
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.image,
            color: Colors.grey,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Build error widget
  Widget _buildErrorWidget() {
    if (errorWidget != null) {
      return SizedBox(
        width: width,
        height: height,
        child: errorWidget,
      );
    }
    
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red[200]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.red,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Wrap image with custom builder if provided
  Widget _wrapWithBuilder(BuildContext context, Widget image) {
    if (builder != null) {
      return builder!(context, image);
    }
    return image;
  }
}

/// Extended platform-aware image with loading states
class PlatformAwareImageExtended extends StatefulWidget {
  final String? imagePath;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Widget)? builder;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool useCache;
  final Duration fadeInDuration;
  final Widget? loadingWidget;

  const PlatformAwareImageExtended({
    super.key,
    this.imagePath,
    this.imageUrl,
    this.imageBytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.builder,
    this.placeholder,
    this.errorWidget,
    this.useCache = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.loadingWidget,
  });

  @override
  State<PlatformAwareImageExtended> createState() => _PlatformAwareImageExtendedState();
}

class _PlatformAwareImageExtendedState extends State<PlatformAwareImageExtended>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startFadeIn() {
    if (!_hasError) {
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  void _showError() {
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (_isLoading) {
      return _buildLoadingWidget(context);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: PlatformAwareImage(
        imagePath: widget.imagePath,
        imageUrl: widget.imageUrl,
        imageBytes: widget.imageBytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        builder: widget.builder,
        placeholder: null, // Handled by loading state
        errorWidget: null, // Handled by error state
        useCache: widget.useCache,
      ),
    );
  }

  Widget _buildLoadingWidget(BuildContext context) {
    if (widget.loadingWidget != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.loadingWidget,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorWidget,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red[50],
          border: Border.all(color: Colors.red[200]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                color: Colors.red,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                'Failed to load',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
