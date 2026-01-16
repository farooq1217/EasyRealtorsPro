import 'dart:typed_data';
import 'dart:io' if (dart.library.html) '../platform_stubs/io_stub.dart' as io;
import '../platform_stubs/html_stub.dart' if (dart.library.html) 'dart:html' as html;

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared/shared.dart';

import '../professional_reports.dart' show generateReportSerial, loadCurrentUserFromStorage, loadReportBranding;

/// Shared professional PDF helper used across modules.
class ProfessionalPdfGenerator {
  static const PdfColor _navy = PdfColor.fromInt(0xFF0B1A3A);
  static const PdfColor _lightBorder = PdfColor.fromInt(0xFFE0E0E0);

  /// Builds and saves a professional receipt without blocking the UI.
  static Future<void> generateReceipt({
    required BuildContext context,
    required AppDatabase db,
    required String module,
    required String title,
    String? entityId,
    required List<MapEntry<String, String>> keyValues,
    List<Map<String, String>>? gridRows,
  }) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparing professional receipt...'),
            ],
          ),
        ),
      ),
    );

    try {
      final preloads = await Future.wait([
        _loadFontBytes('assets/fonts/Roboto-Regular.ttf'),
        _loadFontBytes('assets/fonts/Roboto-Bold.ttf'),
        loadCurrentUserFromStorage(),
      ]);

      final baseFontBytes = (preloads[0] as Uint8List?) ?? Uint8List(0);
      final boldFontBytes = (preloads[1] as Uint8List?) ?? Uint8List(0);
      final currentUser = preloads[2] as Map<String, dynamic>?;
      final branding = await loadReportBranding(db: db, currentUser: currentUser);

      final serial = generateReportSerial(prefix: module.take(3).toUpperCase());
      final generatedAtIso = DateTime.now().toUtc().toIso8601String();

      final pdfBytes = await compute(_buildProfessionalPdfInIsolate, {
        'baseFontBytes': baseFontBytes,
        'boldFontBytes': boldFontBytes,
        'branding': branding == null
            ? null
            : {
                'companyName': branding.companyName,
                'address': branding.address,
                'contact': branding.contact,
              },
        'title': title,
        'module': module,
        'entityId': entityId ?? '',
        'serial': serial,
        'generatedAtIso': generatedAtIso,
        'keyValues': keyValues.map((e) => {'k': e.key, 'v': e.value}).toList(),
        'gridRows': (gridRows ?? const [])
            .map((row) => row.map((k, v) => MapEntry(k.toString(), v.toString())))
            .toList(),
      });

      final savedPath = await _saveToDocuments(
        pdfBytes: pdfBytes,
        module: module,
        entityId: entityId?.isNotEmpty == true ? entityId! : serial,
      );

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null
                ? 'Receipt ready'
                : 'Receipt saved to Documents (${savedPath.split(io.Platform.pathSeparator).last})',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );

      // Auto-open share sheet (e.g., WhatsApp)
      if (savedPath != null && savedPath.isNotEmpty && !kIsWeb) {
        final file = XFile(savedPath, mimeType: 'application/pdf');
        await Share.shareXFiles(
          [file],
          text: 'Asalam-o-Alaikum, please find your receipt attached below. Regards.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF generation failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

Future<Uint8List> _buildProfessionalPdfInIsolate(Map<String, dynamic> args) async {
  final baseFontBytes = (args['baseFontBytes'] as Uint8List?) ?? Uint8List(0);
  final boldFontBytes = (args['boldFontBytes'] as Uint8List?) ?? Uint8List(0);
  final branding = args['branding'] as Map?;
  final title = (args['title'] ?? 'Receipt').toString();
  final module = (args['module'] ?? 'Module').toString();
  final entityId = (args['entityId'] ?? '').toString();
  final serial = (args['serial'] ?? '').toString();
  final generatedAtIso = (args['generatedAtIso'] ?? DateTime.now().toUtc().toIso8601String()).toString();
  final keyValues = ((args['keyValues'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => MapEntry((m['k'] ?? '').toString(), (m['v'] ?? '').toString()))
      .where((e) => e.key.trim().isNotEmpty)
      .toList();
  final gridRows = ((args['gridRows'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => m.map((k, v) => MapEntry(k.toString(), v.toString())))
      .toList();

  final fonts = _fontsFromBytes(baseFontBytes: baseFontBytes, boldFontBytes: boldFontBytes);
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: fonts.base,
      bold: fonts.bold,
    ),
  );

  final generatedAt = DateTime.tryParse(generatedAtIso)?.toLocal() ?? DateTime.now();
  final header = _buildHeader(fonts: fonts, branding: branding, title: title, generatedAt: generatedAt, serial: serial);
  final keyValueTable = _buildKeyValueTable(fonts: fonts, entries: keyValues);
  final gridTable = gridRows.isEmpty ? null : _buildGrid(fonts: fonts, rows: gridRows);
  final signatures = _buildSignatureRow(fonts: fonts);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      footer: (ctx) => _buildFooter(fonts: fonts, context: ctx),
      build: (_) => [
        header,
        pw.SizedBox(height: 12),
        keyValueTable,
        if (gridTable != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            '$module Summary',
            style: pw.TextStyle(font: fonts.bold, fontSize: 12, color: ProfessionalPdfGenerator._navy),
          ),
          pw.SizedBox(height: 8),
          gridTable,
        ],
        pw.SizedBox(height: 24),
        signatures,
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

pw.Widget _buildHeader({
  required _IsolateFonts fonts,
  required Map? branding,
  required String title,
  required DateTime generatedAt,
  required String serial,
}) {
  final companyName = (branding?['companyName'] ?? 'Company').toString();
  final address = (branding?['address'] ?? '').toString();
  final contact = (branding?['contact'] ?? '').toString();

  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: ProfessionalPdfGenerator._navy,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(companyName, style: pw.TextStyle(font: fonts.bold, fontSize: 14, color: PdfColors.white)),
                if (address.trim().isNotEmpty)
                  pw.Text(address, style: pw.TextStyle(font: fonts.base, fontSize: 9, color: PdfColors.white)),
                if (contact.trim().isNotEmpty)
                  pw.Text('Phone: $contact', style: pw.TextStyle(font: fonts.base, fontSize: 9, color: PdfColors.white)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(font: fonts.bold, fontSize: 13, color: PdfColors.white)),
                pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(generatedAt)}',
                    style: pw.TextStyle(font: fonts.base, fontSize: 9, color: PdfColors.white)),
                pw.Text('Receipt #: $serial', style: pw.TextStyle(font: fonts.base, fontSize: 9, color: PdfColors.white)),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildKeyValueTable({required _IsolateFonts fonts, required List<MapEntry<String, String>> entries}) {
  final rows = entries
      .map(
        (e) => pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.white),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF5F7FA),
                border: pw.Border.all(color: ProfessionalPdfGenerator._lightBorder, width: 0.6),
              ),
              child: pw.Text(e.key, style: pw.TextStyle(font: fonts.bold, fontSize: 10, color: ProfessionalPdfGenerator._navy)),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: ProfessionalPdfGenerator._lightBorder, width: 0.6),
                  bottom: pw.BorderSide(color: ProfessionalPdfGenerator._lightBorder, width: 0.6),
                  right: pw.BorderSide(color: ProfessionalPdfGenerator._lightBorder, width: 0.6),
                ),
              ),
              child: pw.Text(e.value, style: pw.TextStyle(font: fonts.base, fontSize: 10)),
            ),
          ],
        ),
      )
      .toList();

  return pw.Table(
    columnWidths: {
      0: const pw.FixedColumnWidth(160),
      1: const pw.FlexColumnWidth(),
    },
    children: rows,
  );
}

pw.Widget _buildGrid({required _IsolateFonts fonts, required List<Map<String, String>> rows}) {
  if (rows.isEmpty) return pw.SizedBox();
  final headers = <String>{};
  for (final row in rows) {
    headers.addAll(row.keys);
  }
  final headerList = headers.toList();

  return pw.Table(
    border: pw.TableBorder.all(color: ProfessionalPdfGenerator._lightBorder, width: 0.6),
    columnWidths: {
      for (var i = 0; i < headerList.length; i++) i: const pw.FlexColumnWidth(),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: ProfessionalPdfGenerator._navy),
        children: headerList
            .map(
              (h) => pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(font: fonts.bold, fontSize: 10, color: PdfColors.white),
                ),
              ),
            )
            .toList(),
      ),
      ...rows.map((row) {
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.white),
          children: headerList
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    (row[h] ?? '-').toString(),
                    style: pw.TextStyle(font: fonts.base, fontSize: 10),
                  ),
                ),
              )
              .toList(),
        );
      }),
    ],
  );
}

pw.Widget _buildSignatureRow({required _IsolateFonts fonts}) {
  pw.Widget _line(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 28),
        pw.Container(
          height: 1,
          color: ProfessionalPdfGenerator._lightBorder,
        ),
        pw.SizedBox(height: 6),
        pw.Text(label, style: pw.TextStyle(font: fonts.base, fontSize: 10, color: ProfessionalPdfGenerator._navy)),
      ],
    );
  }

  return pw.Row(
    children: [
      pw.Expanded(child: _line('Authorized Signature')),
      pw.SizedBox(width: 24),
      pw.Expanded(child: _line('Customer Signature')),
    ],
  );
}

pw.Widget _buildFooter({required _IsolateFonts fonts, required pw.Context context}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text('Powered by Easy Realtors Pro', style: pw.TextStyle(font: fonts.base, fontSize: 9, color: const PdfColor.fromInt(0xFF757575))),
      pw.Text('Page ${context.pageNumber}/${context.pagesCount}', style: pw.TextStyle(font: fonts.base, fontSize: 9, color: const PdfColor.fromInt(0xFF757575))),
    ],
  );
}

class _IsolateFonts {
  final pw.Font base;
  final pw.Font bold;
  const _IsolateFonts({required this.base, required this.bold});
}

_IsolateFonts _fontsFromBytes({required Uint8List baseFontBytes, required Uint8List boldFontBytes}) {
  if (baseFontBytes.isEmpty || boldFontBytes.isEmpty) {
    return _IsolateFonts(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
  }
  return _IsolateFonts(
    base: pw.Font.ttf(ByteData.sublistView(baseFontBytes)),
    bold: pw.Font.ttf(ByteData.sublistView(boldFontBytes)),
  );
}

Future<Uint8List?> _loadFontBytes(String assetPath) async {
  try {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

Future<String?> _saveToDocuments({
  required Uint8List pdfBytes,
  required String module,
  required String entityId,
}) async {
  final safeModule = module.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  final safeId = entityId.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : entityId.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  final baseName = '${safeModule}_Receipt_$safeId';

  if (kIsWeb) {
    try {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Attach an anchor to trigger an actual download while also opening a view tab
      final anchor = html.AnchorElement(href: url)
        ..download = '$baseName.pdf'
        ..target = '_blank';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      // Ensure a tab is opened for inline viewing if the browser blocks downloads
      html.window.open(url, '_blank');
      html.Url.revokeObjectUrl(url);
    } catch (_) {
      // Fallback: printing package opens a new tab with the PDF on web
      await Printing.sharePdf(bytes: pdfBytes, filename: '$baseName.pdf');
    }
    return null;
  }

  final dir = await getApplicationDocumentsDirectory();
  final filePath = '${dir.path}${io.Platform.pathSeparator}$baseName.pdf';
  final file = io.File(filePath);
  await file.create(recursive: true);
  await file.writeAsBytes(pdfBytes, flush: true);
  return filePath;
}

extension on String {
  String take(int count) => length <= count ? this : substring(0, count);
}
