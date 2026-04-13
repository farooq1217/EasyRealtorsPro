import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img_pkg;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../firestore_sync_service.dart';
import 'role_utils.dart' as local;

// ============================================================================
// BACKGROUND ISOLATE UTILITIES
// ============================================================================
class BackgroundIsolateUtil {
  /// Run heavy computation in background isolate
  static Future<R> computeInBackground<R, P>(R Function(P) function, P parameter) async {
    return await compute(function, parameter);
  }
}

// ============================================================================
// FIRESTORE QUERY BUILDER
// ============================================================================
Query buildSecureFirestoreQuery({
  required String collection,
  required Map<String, dynamic>? currentUser,
  String? orderBy,
  bool descending = false,
  int? limit,
  String? additionalAgentFilter,
}) {
  if (!FirestoreSyncService().isAvailable) {
    throw Exception('Firestore not available');
  }

  final isSuperAdmin = local.RoleUtils.isSuperAdmin(currentUser);
  final isAgent = local.RoleUtils.isAgent(currentUser);
  final companyId = local.RoleUtils.getUserCompanyId(currentUser);

  // Security: If not super admin, companyId is REQUIRED
  if (!isSuperAdmin && (companyId == null || companyId.isEmpty)) {
    throw Exception('Unauthorized: Missing company context');
  }

  Query query = FirebaseFirestore.instance.collection(collection);

  // Apply company-based filtering for non-super admins
  if (!isSuperAdmin) {
    query = query.where('companyId', isEqualTo: companyId);
  }

  // Apply agent-specific filtering if needed (must come after company filter for compound queries)
  if (isAgent && additionalAgentFilter != null && !isSuperAdmin) {
    final myUserId = currentUser?['id']?.toString();
    if (myUserId != null && myUserId.isNotEmpty) {
      query = query.where(additionalAgentFilter, isEqualTo: myUserId);
    }
  }

  // Apply ordering (must come after where clauses)
  if (orderBy != null) {
    query = query.orderBy(orderBy, descending: descending);
  }

  // Apply pagination limit
  if (limit != null) {
    query = query.limit(limit.clamp(1, 200));
  }

  return query;
}

// ============================================================================
// PDF GENERATION UTILITIES
// ============================================================================

/// Generates PDF in background isolate to prevent UI blocking
/// Shows loading indicator during generation
Future<void> generatePdfInBackground({
  required BuildContext context,
  required Future<Uint8List> Function() pdfBuilder,
  String? loadingMessage,
}) async {
  if (!context.mounted) return;
  
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(loadingMessage ?? 'Generating PDF...'),
        ],
      ),
    ),
  );

  try {
    // Generate PDF bytes (may use isolate internally)
    final pdfBytes = await pdfBuilder();
    
    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading dialog
    
    // Open PDF viewer/print dialog
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
    );
  }
}

/// Helper function to format timestamp for file names
String fmtTs(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
}

/// Validates password according to requirements
String? _validatePassword(String? password) {
  if (password == null || password.isEmpty) {
    return 'Password is required';
  }
  
  // Check length (8-16 characters)
  if (password.length < 8 || password.length > 16) {
    return 'Password must be between 8 and 16 characters';
  }
  
  // Check for at least 1 uppercase letter
  if (!password.contains(RegExp(r'[A-Z]'))) {
    return 'Password must contain at least 1 uppercase letter';
  }
  
  // Check for at least 1 lowercase letter
  if (!password.contains(RegExp(r'[a-z]'))) {
    return 'Password must contain at least 1 lowercase letter';
  }
  
  // Check for at least 1 numeric digit
  if (!password.contains(RegExp(r'[0-9]'))) {
    return 'Password must contain at least 1 numeric digit';
  }
  
  // Check for at least 1 special character
  if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
    return 'Password must contain at least 1 special character (@, #, \$, %, etc.)';
  }
  
  return null; // Password is valid
}

/// Asks user for password with validation
Future<String?> _askPassword(BuildContext context, {String initial = ''}) async {
  final ctl = TextEditingController(text: initial);
  final formKey = GlobalKey<FormState>();
  String? errorMessage;
  
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
      title: const Text('Set Password'),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ctl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                ),
                onChanged: (value) {
                  setState(() {
                    errorMessage = _validatePassword(value);
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Requirements:\n• 8-16 characters\n• 1 uppercase letter\n• 1 lowercase letter\n• 1 numeric digit\n• 1 special character (@, #, \$, %, etc.)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final password = ctl.text.trim();
              final validationError = _validatePassword(password);
              if (validationError != null) {
                setState(() {
                  errorMessage = validationError;
                });
                return;
              }
              Navigator.pop(ctx, password);
            },
            child: const Text('OK'),
          ),
      ],
      ),
    ),
  );
}

/// Saves a PDF with password protection
Future<void> saveProtectedPdf(BuildContext context, Uint8List plainPdfBytes, {required String suggestedBaseName}) async {
  final pwd = await _askPassword(context) ?? 'Farooq123';
  final protectedBytes = await compute(
    _protectPdfBytesInIsolate,
    {
      'plainPdfBytes': plainPdfBytes,
      'password': pwd,
    },
  );

  if (kIsWeb) {
    await Printing.layoutPdf(onLayout: (_) async => protectedBytes);
    return;
  }

  final os = io.Platform.operatingSystem;
  final isMobile = os == 'android' || os == 'ios';
  if (isMobile) {
    await Printing.sharePdf(bytes: protectedBytes, filename: '$suggestedBaseName.pdf');
    return;
  }

  final dir = await getDirectoryPath();
  if (dir == null) return;
  final path = '$dir${io.Platform.pathSeparator}${suggestedBaseName}.pdf';
  await io.File(path).writeAsBytes(protectedBytes, flush: true);
}

/// Protects PDF bytes with password in isolate
Uint8List _protectPdfBytesInIsolate(Map<String, dynamic> args) {
  final plainPdfBytes = args['plainPdfBytes'] as Uint8List;
  final password = (args['password'] ?? '').toString();
  final sdoc = sf.PdfDocument(inputBytes: plainPdfBytes);
  final security = sdoc.security;
  security.userPassword = password;
  security.ownerPassword = password;
  final protectedBytes = sdoc.saveSync();
  sdoc.dispose();
  return Uint8List.fromList(protectedBytes);
}

/// Builds a simple report PDF
Future<Uint8List> buildSimpleReportPdfBytes() async {
  return compute(_buildSimpleReportPdfBytesInIsolate, DateTime.now().toUtc().toIso8601String());
}

/// Builds a simple report PDF in isolate
Future<Uint8List> _buildSimpleReportPdfBytesInIsolate(String generatedAtIso) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (ctx) => pw.Column(children: [
        pw.Text('Admin Reports', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('Generated at: $generatedAtIso'),
      ]),
    ),
  );
  return await pdf.save();
}

/// Converts image bytes to single page PDF
Future<Uint8List> imageToSinglePagePdf(Uint8List bytes) async {
  return compute(_imageToSinglePagePdfInIsolate, bytes);
}

/// Converts image bytes to single page PDF in isolate
Future<Uint8List> _imageToSinglePagePdfInIsolate(Uint8List bytes) async {
  final doc = pw.Document();
  final img = pw.MemoryImage(bytes);
  doc.addPage(pw.Page(build: (c) => pw.Center(child: pw.Image(img))));
  return await doc.save();
}

/// Converts SVG string to PDF
Future<Uint8List> svgStringToPdf(String svg) async {
  return compute(_svgStringToPdfInIsolate, svg);
}

/// Converts SVG string to PDF in isolate
Future<Uint8List> _svgStringToPdfInIsolate(String svg) async {
  final doc = pw.Document();
  doc.addPage(pw.Page(build: (c) => pw.Column(children: [
        pw.Text('SVG Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('Embedded SVG content below (saved as password-protected PDF):'),
        pw.SizedBox(height: 12),
        pw.Text(svg, style: const pw.TextStyle(fontSize: 8)),
      ])));
  return await doc.save();
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Extracts creator fields from user object for Firestore sync
Map<String, dynamic> creatorFields(Map<String, dynamic>? user) {
  final internalId = user?['id']?.toString().trim();
  final emailKey = (user?['email'] ?? user?['username'])?.toString().trim().toLowerCase();
  final displayNameRaw = (user?['name'] ?? user?['fullName'] ?? user?['displayName'] ?? user?['email'])?.toString().trim();
  final aliasRaw = (user?['user_id'] ?? user?['userId'] ?? user?['user_id_alias'] ?? user?['userIdAlias'])?.toString().trim();
  final resolvedAlias = (emailKey != null && emailKey.isNotEmpty)
      ? emailKey
      : ((aliasRaw != null && aliasRaw.isNotEmpty)
          ? aliasRaw
          : ((internalId != null && internalId.isNotEmpty) ? internalId : null));
  final resolvedDisplayName = (displayNameRaw != null && displayNameRaw.isNotEmpty)
      ? displayNameRaw
      : ((internalId != null && internalId.isNotEmpty) ? internalId : null);
  return {
    'creator_user_id': resolvedAlias,
    'creator_display_name': resolvedDisplayName,
    'creator_user_id_alias': resolvedAlias,
    'creatorUserId': resolvedAlias,
    'creatorDisplayName': resolvedDisplayName,
    'creatorUserIdAlias': resolvedAlias,
  };
}

/// Shows a custom styled date picker dialog
Future<DateTime?> showCustomDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  return await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate ?? DateTime(2000),
    lastDate: lastDate ?? DateTime(2100),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: const Color(0xFFFF6B35), // Orange
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.grey.shade800,
          ),
          dialogBackgroundColor: Colors.white,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      );
    },
  );
}

// ============================================================================
// IMAGE HANDLING FUNCTIONS
// ============================================================================
// Note: Validation functions are in lib/core/shared_utils.dart

/// Platform-aware image widget
/// On web, uses Image.memory if bytes are available, otherwise shows placeholder
/// On mobile/desktop, uses Image.file
Widget buildPlatformImage(String imagePath, {BoxFit fit = BoxFit.cover, Widget? errorWidget}) {
  if (kIsWeb) {
    // For web, we need to load from URL or use bytes
    // Since we're storing paths, we'll need to handle this differently
    // For now, return a placeholder or load from Firestore URL if available
    return Image.network(
      imagePath,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => errorWidget ?? const Icon(Icons.broken_image),
    );
  } else {
    return Image.file(
      io.File(imagePath) as dynamic,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => errorWidget ?? const Icon(Icons.broken_image),
    );
  }
}

/// Compresses an image to 1MB or smaller
/// Returns the compressed image bytes and the file path
/// Accepts XFile (all platforms) or File (desktop/mobile)
Future<Map<String, dynamic>?> compressImage(dynamic imageFile) async {
  try {
    Uint8List originalBytes;
    String? originalPath;
    
    // Handle both XFile (all platforms) and File (desktop/mobile)
    if (imageFile is XFile) {
      originalBytes = await imageFile.readAsBytes();
      originalPath = imageFile.path;
    } else if (!kIsWeb && imageFile is io.File) {
      originalBytes = await imageFile.readAsBytes();
      originalPath = imageFile.path;
    } else if (imageFile is Uint8List) {
      originalBytes = imageFile;
      originalPath = null;
    } else {
      return null;
    }
    
    final originalSize = originalBytes.length;
    
    // If already under 1MB, return as is
    if (originalSize <= 1024 * 1024) {
      return {
        'bytes': originalBytes,
        'path': originalPath ?? '',
        'size': originalSize,
      };
    }
    
    // Decode image
    final img = img_pkg.decodeImage(originalBytes);
    if (img == null) return null;
    
    // Calculate target dimensions to achieve ~1MB
    // Start with 90% quality and reduce dimensions if needed
    int quality = 90;
    int width = img.width;
    int height = img.height;
    Uint8List? compressedBytes;
    
    while (quality > 10) {
      // Resize if needed
      img_pkg.Image resized = img;
      if (width > 2000 || height > 2000) {
        final ratio = 2000 / (width > height ? width : height);
        width = (width * ratio).round();
        height = (height * ratio).round();
        resized = img_pkg.copyResize(img, width: width, height: height);
      }
      
      // Encode with quality
      compressedBytes = Uint8List.fromList(
        img_pkg.encodeJpg(resized, quality: quality)
      );
      
      if (compressedBytes.length <= 1024 * 1024) {
        break;
      }
      
      quality -= 10;
    }
    
    if (compressedBytes == null || compressedBytes.length > 1024 * 1024) {
      // If still too large, force resize to smaller dimensions
      final ratio = 0.7;
      width = (img.width * ratio).round();
      height = (img.height * ratio).round();
      final resized = img_pkg.copyResize(img, width: width, height: height);
      compressedBytes = Uint8List.fromList(
        img_pkg.encodeJpg(resized, quality: 75)
      );
    }
    
    // Save compressed image to temp file (desktop/mobile only)
    String? compressedPath;
    if (!kIsWeb) {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = io.File('${tempDir.path}/compressed_$timestamp.jpg');
      await compressedFile.writeAsBytes(compressedBytes);
      compressedPath = compressedFile.path;
    } else {
      // For web, use a placeholder path (actual file handling is different)
      compressedPath = 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    
    return {
      'bytes': compressedBytes,
      'path': compressedPath ?? originalPath ?? '',
      'size': compressedBytes.length,
    };
  } catch (e) {
    return null;
  }
}

/// Shows image source selection dialog (Camera or Gallery)
Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
  return showDialog<ImageSource>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Select Image Source'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Picks and compresses an image from camera or gallery
Future<Map<String, dynamic>?> pickAndCompressImage(BuildContext context, ImageSource source) async {
  try {
    final picker = ImagePicker();
    XFile? pickedFile;
    
    if (source == ImageSource.camera) {
      pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // We'll compress manually
      );
    } else {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // We'll compress manually
      );
    }
    
    if (pickedFile == null) return null;
    
    // On web, XFile works directly. On mobile/desktop, we can check if file exists
    dynamic file;
    if (!kIsWeb) {
      file = io.File(pickedFile.path);
      if (!await file.exists()) return null;
    } else {
      file = pickedFile; // Use XFile directly on web
    }
    
    // Check file extension
    final extension = p.extension(pickedFile.path).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only JPG, PNG, and WEBP formats are supported')),
        );
      }
      return null;
    }
    
    // Compress image
    final compressed = await compressImage(file);
    if (compressed == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process image')),
        );
      }
      return null;
    }
    
    return compressed;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
    return null;
  }
}

/// Saves image to app directory and returns the saved path
Future<String?> saveImageToAppDir(Uint8List imageBytes, String module, String recordId) async {
  try {
    if (kIsWeb) {
      // On web, we can't save to file system directly
      // Return a placeholder path or handle differently
      return 'web_image_${recordId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = io.Directory('${appDir.path}/images/$module');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${recordId}_$timestamp.jpg';
    final filePath = '${imagesDir.path}/$fileName';
    final file = io.File(filePath);
    await file.writeAsBytes(imageBytes);
    
    return filePath;
  } catch (e) {
    return null;
  }
}

/// Uploads image bytes to Firebase Storage and returns the download URL
Future<String?> uploadImageToFirebaseStorage({
  required Uint8List imageBytes,
  required String module,
  required String recordId,
  String? fileName,
}) async {
  try {
    final storage = FirebaseStorage.instance;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final name = fileName ?? '${recordId}_$timestamp.jpg';
    final path = 'inventory/$module/$recordId/$name';
    
    final ref = storage.ref().child(path);
    final uploadTask = ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    
    await uploadTask;
    final downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  } catch (e) {
    debugPrint('Error uploading image to Firebase Storage: $e');
    return null;
  }
}

/// Uploads multiple images to Firebase Storage and returns list of URLs
Future<List<String>> uploadImagesToFirebaseStorage({
  required List<Uint8List> imageBytesList,
  required String module,
  required String recordId,
}) async {
  final urls = <String>[];
  for (int i = 0; i < imageBytesList.length; i++) {
    final url = await uploadImageToFirebaseStorage(
      imageBytes: imageBytesList[i],
      module: module,
      recordId: recordId,
      fileName: 'image_$i.jpg',
    );
    if (url != null) {
      urls.add(url);
    }
  }
  return urls;
}

/// Converts list of image URLs to JSON string for storage
String imageUrlsToJson(List<String> urls) {
  return jsonEncode(urls);
}

/// Converts JSON string to list of image URLs
List<String> jsonToImageUrls(String? jsonString) {
  if (jsonString == null || jsonString.isEmpty) return [];
  try {
    final decoded = jsonDecode(jsonString) as List;
    return decoded.map((e) => e.toString()).toList();
  } catch (e) {
    return [];
  }
}

// ============================================================================
// PDF EXPORT FUNCTIONS
// ============================================================================

Future<void> exportReportPng(BuildContext context) async {
  final pdfBytes = await buildSimpleReportPdfBytes();
  final rasters = await Printing.raster(pdfBytes, pages: const [0], dpi: 144).toList();
  if (rasters.isEmpty) return;
  final png = await rasters.first.toPng();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('PNG Preview'),
      content: Builder(
        builder: (context) {
          final size = MediaQuery.of(context).size;
          final w = size.width < 980 ? size.width * 0.9 : 900.0;
          final h = size.height < 620 ? size.height * 0.7 : 520.0;
          return SizedBox(
            width: w,
            height: h,
            child: SingleChildScrollView(child: Image.memory(png)),
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton.icon(onPressed: () async { await saveProtectedPdf(context, await imageToSinglePagePdf(png), suggestedBaseName: 'report_${fmtTs(DateTime.now())}_png'); if (context.mounted) Navigator.pop(ctx); }, icon: const Icon(Icons.lock), label: const Text('Download (Password PDF)')),
      ],
    ),
  );
}

Future<void> exportReportJpg(BuildContext context) async {
  final pdfBytes = await buildSimpleReportPdfBytes();
  final rasters = await Printing.raster(pdfBytes, pages: const [0], dpi: 144).toList();
  if (rasters.isEmpty) return;
  final pngBytes = await rasters.first.toPng();
  final img = img_pkg.decodePng(pngBytes);
  if (img == null) return;
  final jpgBytes = img_pkg.encodeJpg(img, quality: 90);
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('JPG Preview'),
      content: Builder(
        builder: (context) {
          final size = MediaQuery.of(context).size;
          final w = size.width < 980 ? size.width * 0.9 : 900.0;
          final h = size.height < 620 ? size.height * 0.7 : 520.0;
          return SizedBox(
            width: w,
            height: h,
            child: SingleChildScrollView(child: Image.memory(Uint8List.fromList(jpgBytes))),
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton.icon(onPressed: () async { await saveProtectedPdf(context, await imageToSinglePagePdf(Uint8List.fromList(jpgBytes)), suggestedBaseName: 'report_${fmtTs(DateTime.now())}_jpg'); if (context.mounted) Navigator.pop(ctx); }, icon: const Icon(Icons.lock), label: const Text('Download (Password PDF)')),
      ],
    ),
  );
}

Future<void> exportReportSvg(BuildContext context) async {
  final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="800" height="400">'
      '<rect width="100%" height="100%" fill="white"/>'
      '<text x="50%" y="40%" dominant-baseline="middle" text-anchor="middle" font-size="28" font-family="Arial" fill="black">Admin Reports</text>'
      '<text x="50%" y="55%" dominant-baseline="middle" text-anchor="middle" font-size="14" font-family="Arial" fill="black">Generated at: ${DateTime.now().toLocal()}</text>'
      '</svg>';
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('SVG Preview'),
      content: Builder(
        builder: (context) {
          final size = MediaQuery.of(context).size;
          final w = size.width < 980 ? size.width * 0.9 : 900.0;
          final h = size.height < 620 ? size.height * 0.7 : 520.0;
          return SizedBox(
            width: w,
            height: h,
            child: SingleChildScrollView(child: SvgPicture.string(svg)),
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton.icon(onPressed: () async { final bytes = await svgStringToPdf(svg); await saveProtectedPdf(context, bytes, suggestedBaseName: 'report_${fmtTs(DateTime.now())}_svg'); if (context.mounted) Navigator.pop(ctx); }, icon: const Icon(Icons.lock), label: const Text('Download (Password PDF)')),
      ],
    ),
  );
}

Future<void> exportProtectedPdf(BuildContext context) async {
  try {
    final plainBytes = await buildSimpleReportPdfBytes();
    // Use saveProtectedPdf from app_utils.dart which handles protection internally
    await saveProtectedPdf(context, plainBytes, suggestedBaseName: 'report_${fmtTs(DateTime.now())}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

/// Get the first available company ID for super admin operations
Future<String> _getFirstCompanyId(dynamic db) async {
  try {
    final result = await db.customSelect('SELECT id FROM companies WHERE is_active = 1 LIMIT 1', variables: []).get();
    if (result.isNotEmpty) {
      return result.first.data['id'] as String;
    }
  } catch (e) {
    debugPrint('Error getting first company ID: $e');
  }
  // Fallback to a timestamp-based ID if no companies exist
  return DateTime.now().millisecondsSinceEpoch.toString();
}

