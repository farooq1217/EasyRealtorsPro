import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import '../core/app_utils.dart' show pickAndCompressImage, showImageSourceDialog;
import '../image_cache_service.dart' show CachedImageWidget;

/// Reusable Image Upload Widget
class ImageUploadWidget extends StatefulWidget {
  final List<String> imagePaths;
  final Function(List<String>) onImagesChanged;
  final int maxImages;
  
  const ImageUploadWidget({
    super.key,
    required this.imagePaths,
    required this.onImagesChanged,
    this.maxImages = 3,
  });
  
  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  List<String> get _images => widget.imagePaths;
  
  Future<void> _uploadImage() async {
    if (_images.length >= widget.maxImages) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum ${widget.maxImages} images allowed')),
        );
      }
      return;
    }
    
    final source = await showImageSourceDialog(context);
    if (source == null) return;
    
    final result = await pickAndCompressImage(context, source);
    if (result != null && mounted) {
      setState(() {
        _images.add(result['path'] as String);
        widget.onImagesChanged(List.from(_images));
      });
    }
  }
  
  void _deleteImage(int index) {
    if (index >= 0 && index < _images.length) {
      final imagePath = _images[index];
      // Delete file from disk
      try {
        if (!kIsWeb) {
          final file = io.File(imagePath);
          if (file.existsSync()) {
            file.deleteSync();
            debugPrint('Deleted image file: $imagePath');
          }
        } else {
          debugPrint('Image deletion on web: $imagePath');
        }
      } catch (e) {
        debugPrint('Error deleting image file: $e');
        // Continue even if file deletion fails
      }
      // Remove from list
      setState(() {
        _images.removeAt(index);
        widget.onImagesChanged(List.from(_images));
      });
    }
  }
  
  void _previewImage(int index) {
    final imagePath = _images[index];
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Stack(
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
              child: CachedImageWidget(
                imagePath: imagePath,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteImage(index);
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _uploadImage,
          icon: const Icon(Icons.upload),
          label: const Text('Upload Image'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_images.length, (index) {
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => _previewImage(index),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedImageWidget(
                          imagePath: _images[index],
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorWidget: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _deleteImage(index),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ],
    );
  }
}

