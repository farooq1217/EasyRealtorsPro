import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'dart:io' if (dart.library.html) 'platform_stubs/io_stub.dart' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as d;
import 'package:file_selector/file_selector.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/shared.dart';

import 'core/services/auth_service.dart';
import 'core/models/expenditure_model.dart';
import 'image_cache_service.dart';

class ReportBranding {
  final String companyId;
  final String companyName;
  final String? address;
  final String? contact;
  final String? logoPathOrUrl;

  const ReportBranding({
    required this.companyId,
    required this.companyName,
    required this.address,
    required this.contact,
    required this.logoPathOrUrl,
  });
}

class ReportMeta {
  final String title;
  final String serialNumber;
  final DateTime generatedAt;

  const ReportMeta({
    required this.title,
    required this.serialNumber,
    required this.generatedAt,
  });
}

class ReportFonts {
  final pw.Font base;
  final pw.Font bold;

  const ReportFonts({required this.base, required this.bold});

  static Future<ReportFonts> load() async {
    try {
      final baseBytes = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final boldBytes = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final base = pw.Font.ttf(baseBytes);
      final bold = pw.Font.ttf(boldBytes);
      return ReportFonts(base: base, bold: bold);
    } catch (_) {
      return ReportFonts(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
    }
  }
}

Future<Map<String, dynamic>> _readLocalSettings() async {
  if (kIsWeb) return {};
  try {
    final dir = await getApplicationSupportDirectory();
    final app = io.Directory('${dir.path}${io.Platform.pathSeparator}desktop_admin');
    final file = io.File('${app.path}${io.Platform.pathSeparator}settings.json');
    if (!await file.exists()) return {};
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return {};
  } catch (_) {
    return {};
  }
}

String generateReportSerial({String prefix = 'RPT'}) {
  final now = DateTime.now().toUtc();
  final two = (int n) => n.toString().padLeft(2, '0');
  final base = '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}-${now.millisecond.toString().padLeft(3, '0')}';
  final rand = Random().nextInt(10000).toString().padLeft(4, '0');
  return '$prefix-$base-$rand';
}

Future<Map<String, dynamic>?> loadCurrentUserFromStorage() async {
  try {
    final s = await _readLocalSettings();
    final authToken = s['authToken'] as String?;
    if (authToken == null || authToken.trim().isEmpty) return null;
    return await AuthService().getCurrentUser(authToken);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _parseCompanyMetadata(dynamic raw) {
  if (raw == null) return const {};
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return const {};
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return const {};
}

String? _pickString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

Future<ReportBranding?> loadReportBranding({
  required AppDatabase db,
  required Map<String, dynamic>? currentUser,
}) async {
  final isSuperAdmin = RoleUtils.isSuperAdmin(currentUser);
  final companyId = RoleUtils.getUserCompanyId(currentUser);
  final effectiveCompanyId = isSuperAdmin ? companyId : companyId;
  if (effectiveCompanyId == null || effectiveCompanyId.trim().isEmpty) return null;

  String companyName = '';
  dynamic metadata;
  String? address;
  String? contact;
  String? logo;

  try {
    final res = await db.customSelect(
      'SELECT id, name, metadata, address, contact, logo_url FROM companies WHERE id = ? LIMIT 1',
      variables: [d.Variable.withString(effectiveCompanyId)],
    ).get();
    if (res.isNotEmpty) {
      companyName = res.first.data['name']?.toString() ?? '';
      metadata = res.first.data['metadata'];
      address = (res.first.data['address'])?.toString();
      contact = (res.first.data['contact'])?.toString();
      logo = (res.first.data['logo_url'])?.toString();
    }
  } catch (_) {}

  if (Firebase.apps.isNotEmpty) {
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(effectiveCompanyId).get();
      final data = doc.data();
      if (data != null) {
        companyName = companyName.isNotEmpty ? companyName : (data['name']?.toString() ?? '');
        metadata = metadata ?? data['metadata'];
        address = (address == null || address!.trim().isEmpty) ? (data['address']?.toString()) : address;
        contact = (contact == null || contact!.trim().isEmpty) ? (data['contact']?.toString()) : contact;
        logo = (logo == null || logo!.trim().isEmpty) ? ((data['logoUrl'] ?? data['logo_url'])?.toString()) : logo;
      }
    } catch (_) {}
  }

  companyName = companyName.trim();
  if (companyName.isEmpty) companyName = 'Company';

  final meta = _parseCompanyMetadata(metadata);
  address = (address ?? '').trim().isNotEmpty ? address : _pickString(meta, const ['address', 'companyAddress', 'company_address']);
  contact = (contact ?? '').trim().isNotEmpty ? contact : _pickString(meta, const ['contact', 'contactNo', 'contact_no', 'phone', 'mobile', 'email']);
  logo = (logo ?? '').trim().isNotEmpty ? logo : _pickString(meta, const ['logo', 'logoPath', 'logo_path', 'logoUrl', 'logo_url', 'companyLogo', 'company_logo']);

  return ReportBranding(
    companyId: effectiveCompanyId,
    companyName: companyName,
    address: address,
    contact: contact,
    logoPathOrUrl: logo,
  );
}

Future<Uint8List?> _tryLoadRobotoBytes(String assetPath) async {
  try {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

Future<Uint8List> _buildExpenseStatementPdfInIsolate(Map<String, dynamic> args) async {
  final baseFontBytes = (args['baseFontBytes'] as Uint8List?) ?? Uint8List(0);
  final boldFontBytes = (args['boldFontBytes'] as Uint8List?) ?? Uint8List(0);
  final logoBytes = args['logoBytes'] as Uint8List?;

  final formatMap = (args['format'] as Map).cast<String, dynamic>();
  final format = PdfPageFormat(
    (formatMap['width'] as num).toDouble(),
    (formatMap['height'] as num).toDouble(),
    marginLeft: (formatMap['marginLeft'] as num).toDouble(),
    marginRight: (formatMap['marginRight'] as num).toDouble(),
    marginTop: (formatMap['marginTop'] as num).toDouble(),
    marginBottom: (formatMap['marginBottom'] as num).toDouble(),
  );

  final fonts = ReportFonts(
    base: baseFontBytes.isEmpty ? pw.Font.helvetica() : pw.Font.ttf(ByteData.sublistView(baseFontBytes)),
    bold: boldFontBytes.isEmpty ? pw.Font.helveticaBold() : pw.Font.ttf(ByteData.sublistView(boldFontBytes)),
  );

  final brandingMap = (args['branding'] as Map?)?.cast<String, dynamic>();
  final branding = brandingMap == null
      ? null
      : ReportBranding(
          companyId: (brandingMap['companyId'] ?? '').toString(),
          companyName: (brandingMap['companyName'] ?? '').toString(),
          address: (brandingMap['address'] as String?),
          contact: (brandingMap['contact'] as String?),
          logoPathOrUrl: null,
        );

  final meta = ReportMeta(
    title: (args['title'] ?? '').toString(),
    serialNumber: (args['serialNumber'] ?? '').toString(),
    generatedAt: DateTime.parse((args['generatedAtIso'] ?? DateTime.now().toUtc().toIso8601String()).toString()).toLocal(),
  );

  final groupByCategory = args['groupByCategory'] == true;
  final rowsRaw = (args['rows'] as List).cast<Map>();
  final rows = rowsRaw.map((m) => ExpenditureModel.fromMap(Map<String, dynamic>.from(m))).toList();

  final logoImage = logoBytes == null ? null : pw.MemoryImage(logoBytes);
  final currency = NumberFormat('#,##0.00');
  final total = rows.fold<double>(0, (s, e) => s + e.amount);

  final grouped = <String, List<ExpenditureModel>>{};
  String categoryOf(ExpenditureModel e) {
    final c = (e.category ?? '').trim();
    if (c.isNotEmpty) return c;
    final d = e.description.trim();
    if (d.contains(' - ')) return d.split(' - ').first.trim();
    if (d.contains(':')) return d.split(':').first.trim();
    return 'General';
  }

  for (final e in rows) {
    final key = groupByCategory ? categoryOf(e) : 'All';
    grouped.putIfAbsent(key, () => []).add(e);
  }

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: fonts.base,
      bold: fonts.bold,
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => buildReportHeader(fonts: fonts, branding: branding, meta: meta, logoImage: logoImage),
      footer: (ctx) => buildReportFooter(fonts: fonts, context: ctx),
      build: (ctx) {
        final blocks = <pw.Widget>[];

        final keys = grouped.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        for (final k in keys) {
          final items = grouped[k] ?? const [];
          final subtotal = items.fold<double>(0, (s, e) => s + e.amount);

          if (groupByCategory) {
            blocks.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3F2FD)),
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text(k, style: pw.TextStyle(font: fonts.bold, fontSize: 11))),
                    pw.Text('Subtotal: Rs ${currency.format(subtotal)}', style: pw.TextStyle(font: fonts.bold, fontSize: 11)),
                  ],
                ),
              ),
            );
            blocks.add(pw.SizedBox(height: 8));
          }

          blocks.add(
            zebraTable(
              fonts: fonts,
              headers: const ['Date', 'Description', 'Amount'],
              columnWidths: {
                0: const pw.FixedColumnWidth(90),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(95),
              },
              rows: items
                  .map(
                    (e) => [
                      pw.Text(e.date),
                      pw.Text(e.description),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text('Rs ${currency.format(e.amount)}'),
                      ),
                    ],
                  )
                  .toList(),
            ),
          );
          blocks.add(pw.SizedBox(height: 14));
        }

        blocks.add(
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total Summary: Rs ${currency.format(total)}',
              style: pw.TextStyle(font: fonts.bold, fontSize: 12),
            ),
          ),
        );

        return blocks;
      },
    ),
  );

  return Uint8List.fromList(await doc.save());
}

dynamic _sanitizeForIsolate(dynamic value) {
  if (value == null || value is num || value is bool || value is String) return value;
  if (value is Uint8List) return value;
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is GeoPoint) {
    return <String, dynamic>{'lat': value.latitude, 'lng': value.longitude};
  }
  if (value is Map) {
    final cast = value.cast<Object?, Object?>();
    final out = <String, dynamic>{};
    for (final e in cast.entries) {
      out[e.key?.toString() ?? ''] = _sanitizeForIsolate(e.value);
    }
    return out;
  }
  if (value is List) {
    return value.map(_sanitizeForIsolate).toList();
  }
  return value.toString();
}

Map<String, dynamic> _sanitizeMapForIsolate(Map<String, dynamic> map) {
  final out = <String, dynamic>{};
  for (final e in map.entries) {
    out[e.key] = _sanitizeForIsolate(e.value);
  }
  return out;
}

Future<Uint8List> _buildTradingDealSummaryPdfInIsolate(Map<String, dynamic> args) async {
  final baseFontBytes = (args['baseFontBytes'] as Uint8List?) ?? Uint8List(0);
  final boldFontBytes = (args['boldFontBytes'] as Uint8List?) ?? Uint8List(0);
  final logoBytes = args['logoBytes'] as Uint8List?;

  final formatMap = (args['format'] as Map).cast<String, dynamic>();
  final format = _pdfFormatFromMap(formatMap);
  final fonts = _fontsFromBytes(baseFontBytes: baseFontBytes, boldFontBytes: boldFontBytes);

  final brandingMap = (args['branding'] as Map?)?.cast<String, dynamic>();
  final branding = brandingMap == null
      ? null
      : ReportBranding(
          companyId: (brandingMap['companyId'] ?? '').toString(),
          companyName: (brandingMap['companyName'] ?? '').toString(),
          address: (brandingMap['address'] as String?),
          contact: (brandingMap['contact'] as String?),
          logoPathOrUrl: null,
        );

  final meta = ReportMeta(
    title: (args['title'] ?? '').toString(),
    serialNumber: (args['serialNumber'] ?? '').toString(),
    generatedAt: DateTime.parse((args['generatedAtIso'] ?? DateTime.now().toUtc().toIso8601String()).toString()).toLocal(),
  );

  final entry = Map<String, dynamic>.from((args['entry'] as Map).cast<String, dynamic>());
  final id = (entry['id'] ?? '').toString();
  final dealType = (entry['type'] ?? '').toString().toLowerCase() == 'buy' ? 'Buy' : 'Sell';

  String v(String key) => (entry[key] ?? '').toString().trim();
  String vAny(List<String> keys) {
    for (final k in keys) {
      final s = v(k);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  final logoImage = logoBytes == null ? null : pw.MemoryImage(logoBytes);

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold));
  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => buildReportHeader(fonts: fonts, branding: branding, meta: meta, logoImage: logoImage),
      footer: (ctx) => buildReportFooter(fonts: fonts, context: ctx),
      build: (ctx) {
        final buyerName = vAny(const ['buyer_name', 'buyerName']);
        final sellerName = vAny(const ['seller_name', 'sellerName']);
        final plotNo = vAny(const ['plot_no', 'plotNo']);
        final block = vAny(const ['block']);
        final commission = vAny(const ['commission', 'commissionAmount', 'commission_amount']);

        final infoRows = <List<pw.Widget>>[
          [pw.Text('Deal ID'), pw.Text(id.isEmpty ? 'N/A' : id)],
          [pw.Text('Deal Type'), pw.Text(dealType)],
          [pw.Text('Option'), pw.Text(v('buy_option').isNotEmpty ? v('buy_option') : v('sell_option'))],
          [pw.Text('Date'), pw.Text(v('date'))],
          if (sellerName.isNotEmpty) [pw.Text('Seller Name'), pw.Text(sellerName)],
          if (buyerName.isNotEmpty) [pw.Text('Buyer Name'), pw.Text(buyerName)],
          if (sellerName.isEmpty && buyerName.isEmpty)
            [pw.Text('Person Name'), pw.Text(v('person_name').isEmpty ? '-' : v('person_name'))],
          [pw.Text('Contact'), pw.Text(v('mobile').isEmpty ? '-' : v('mobile'))],
          [pw.Text('Plot / Estate'), pw.Text(v('estate_name').isEmpty ? '-' : v('estate_name'))],
          if (plotNo.isNotEmpty) [pw.Text('Plot No.'), pw.Text(plotNo)],
          if (block.isNotEmpty) [pw.Text('Block'), pw.Text(block)],
          [pw.Text('Quantity'), pw.Text(v('quantity').isEmpty ? '-' : v('quantity'))],
          [pw.Text('Payment'), pw.Text(v('payment').isEmpty ? '-' : 'Rs ${v('payment')}')],
          [pw.Text('Payment Status'), pw.Text(v('status').isEmpty ? '-' : v('status'))],
          [pw.Text('Commission'), pw.Text(commission.isEmpty ? 'N/A' : commission)],
        ];

        return [
          pw.Text('Deal Details', style: pw.TextStyle(font: fonts.bold, fontSize: 13)),
          pw.SizedBox(height: 10),
          zebraTable(
            fonts: fonts,
            headers: const ['Field', 'Value'],
            columnWidths: {
              0: const pw.FixedColumnWidth(140),
              1: const pw.FlexColumnWidth(),
            },
            rows: infoRows,
          ),
          pw.SizedBox(height: 14),
          if (v('comments').isNotEmpty) ...[
            pw.Text('Remarks', style: pw.TextStyle(font: fonts.bold, fontSize: 12)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFBDBDBD)),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(v('comments')),
            ),
          ],
        ];
      },
    ),
  );

  return Uint8List.fromList(await doc.save());
}

Future<Uint8List> _buildPropertyCatalogPdfInIsolate(Map<String, dynamic> args) async {
  final baseFontBytes = (args['baseFontBytes'] as Uint8List?) ?? Uint8List(0);
  final boldFontBytes = (args['boldFontBytes'] as Uint8List?) ?? Uint8List(0);
  final logoBytes = args['logoBytes'] as Uint8List?;

  final formatMap = (args['format'] as Map).cast<String, dynamic>();
  final format = _pdfFormatFromMap(formatMap);
  final fonts = _fontsFromBytes(baseFontBytes: baseFontBytes, boldFontBytes: boldFontBytes);

  final brandingMap = (args['branding'] as Map?)?.cast<String, dynamic>();
  final branding = brandingMap == null
      ? null
      : ReportBranding(
          companyId: (brandingMap['companyId'] ?? '').toString(),
          companyName: (brandingMap['companyName'] ?? '').toString(),
          address: (brandingMap['address'] as String?),
          contact: (brandingMap['contact'] as String?),
          logoPathOrUrl: null,
        );

  final meta = ReportMeta(
    title: (args['title'] ?? '').toString(),
    serialNumber: (args['serialNumber'] ?? '').toString(),
    generatedAt: DateTime.parse((args['generatedAtIso'] ?? DateTime.now().toUtc().toIso8601String()).toString()).toLocal(),
  );

  final propertyData = Map<String, dynamic>.from((args['propertyData'] as Map).cast<String, dynamic>());
  final societyBlock = Map<String, String>.from((args['societyBlock'] as Map).cast<String, String>());
  final imageBytes = (args['imageBytes'] as List?)?.cast<Uint8List?>() ?? const <Uint8List?>[];

  final id = (propertyData['id'] ?? '').toString();
  String val(String k) => (propertyData[k] ?? '').toString().trim();

  final details = <List<pw.Widget>>[
    [pw.Text('Property ID'), pw.Text(id.isEmpty ? 'N/A' : id)],
    [pw.Text('Category'), pw.Text(val('file_no').isEmpty ? 'N/A' : val('file_no'))],
    [pw.Text('Plot No.'), pw.Text(val('reference_no').isEmpty ? 'N/A' : val('reference_no'))],
    [pw.Text('Size'), pw.Text(val('price').isEmpty ? 'N/A' : val('price'))],
    [pw.Text('Society'), pw.Text((societyBlock['society'] ?? '').isEmpty ? 'N/A' : (societyBlock['society'] ?? ''))],
    [pw.Text('Block'), pw.Text((societyBlock['block'] ?? '').isEmpty ? 'N/A' : (societyBlock['block'] ?? ''))],
    [pw.Text('Owner Name'), pw.Text(val('client_name').isEmpty ? 'N/A' : val('client_name'))],
    [pw.Text('Contact No.'), pw.Text(val('property_name').isEmpty ? 'N/A' : val('property_name'))],
    [pw.Text('CNIC'), pw.Text(val('cnic').isEmpty ? 'N/A' : val('cnic'))],
    [pw.Text('Demand'), pw.Text(val('demand').isEmpty ? 'N/A' : 'Rs ${val('demand')}')],
    [pw.Text('Status'), pw.Text(val('sale_status').isEmpty ? 'N/A' : val('sale_status'))],
  ];

  pw.Widget imageBox(String label, Uint8List? bytes) {
    if (bytes == null) {
      return pw.Container(
        height: 140,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFBDBDBD)),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text(
            label,
            style: pw.TextStyle(font: fonts.base, fontSize: 10, color: const PdfColor.fromInt(0xFF616161)),
          ),
        ),
      );
    }
    final img = pw.MemoryImage(bytes);
    return pw.Container(
      height: 140,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFBDBDBD)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: pw.Image(img, fit: pw.BoxFit.cover),
      ),
    );
  }

  final imgWidgets = <pw.Widget>[];
  for (var i = 0; i < 3; i++) {
    final bytes = i < imageBytes.length ? imageBytes[i] : null;
    imgWidgets.add(imageBox('Property Image ${i + 1}', bytes));
  }

  final logoImage = logoBytes == null ? null : pw.MemoryImage(logoBytes);
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold));
  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => buildReportHeader(fonts: fonts, branding: branding, meta: meta, logoImage: logoImage),
      footer: (ctx) => buildReportFooter(fonts: fonts, context: ctx),
      build: (ctx) {
        return [
          pw.Text('Technical Details', style: pw.TextStyle(font: fonts.bold, fontSize: 13)),
          pw.SizedBox(height: 10),
          zebraTable(
            fonts: fonts,
            headers: const ['Field', 'Value'],
            columnWidths: {
              0: const pw.FixedColumnWidth(140),
              1: const pw.FlexColumnWidth(),
            },
            rows: details,
          ),
          pw.SizedBox(height: 14),
          pw.Text('Property Images', style: pw.TextStyle(font: fonts.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: imgWidgets[0]),
              pw.SizedBox(width: 10),
              pw.Expanded(child: imgWidgets[1]),
              pw.SizedBox(width: 10),
              pw.Expanded(child: imgWidgets[2]),
            ],
          ),
          if (val('remarks').isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('Remarks', style: pw.TextStyle(font: fonts.bold, fontSize: 12)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFBDBDBD)),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(val('remarks')),
            ),
          ],
        ];
      },
    ),
  );

  return Uint8List.fromList(await doc.save());
}

PdfPageFormat _pdfFormatFromMap(Map<String, dynamic> formatMap) {
  return PdfPageFormat(
    (formatMap['width'] as num).toDouble(),
    (formatMap['height'] as num).toDouble(),
    marginLeft: (formatMap['marginLeft'] as num).toDouble(),
    marginRight: (formatMap['marginRight'] as num).toDouble(),
    marginTop: (formatMap['marginTop'] as num).toDouble(),
    marginBottom: (formatMap['marginBottom'] as num).toDouble(),
  );
}

ReportFonts _fontsFromBytes({required Uint8List baseFontBytes, required Uint8List boldFontBytes}) {
  if (baseFontBytes.isEmpty || boldFontBytes.isEmpty) {
    return ReportFonts(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold());
  }

  return ReportFonts(
    base: pw.Font.ttf(ByteData.sublistView(baseFontBytes)),
    bold: pw.Font.ttf(ByteData.sublistView(boldFontBytes)),
  );
}

Future<Uint8List> _buildKeyValueReportPdfInIsolate(Map<String, dynamic> args) async {
  final baseFontBytes = (args['baseFontBytes'] as Uint8List?) ?? Uint8List(0);
  final boldFontBytes = (args['boldFontBytes'] as Uint8List?) ?? Uint8List(0);
  final logoBytes = args['logoBytes'] as Uint8List?;

  final formatMap = (args['format'] as Map).cast<String, dynamic>();
  final format = _pdfFormatFromMap(formatMap);

  final fonts = _fontsFromBytes(baseFontBytes: baseFontBytes, boldFontBytes: boldFontBytes);

  final brandingMap = (args['branding'] as Map?)?.cast<String, dynamic>();
  final branding = brandingMap == null
      ? null
      : ReportBranding(
          companyId: (brandingMap['companyId'] ?? '').toString(),
          companyName: (brandingMap['companyName'] ?? '').toString(),
          address: (brandingMap['address'] as String?),
          contact: (brandingMap['contact'] as String?),
          logoPathOrUrl: null,
        );

  final meta = ReportMeta(
    title: (args['title'] ?? '').toString(),
    serialNumber: (args['serialNumber'] ?? '').toString(),
    generatedAt: DateTime.parse((args['generatedAtIso'] ?? DateTime.now().toUtc().toIso8601String()).toString()).toLocal(),
  );

  final rowsRaw = (args['fields'] as List?) ?? const [];
  final fields = rowsRaw
      .map((e) {
        if (e is Map) {
          final m = e.cast<String, dynamic>();
          return MapEntry((m['k'] ?? '').toString(), (m['v'] ?? '').toString());
        }
        return const MapEntry<String, String>('', '');
      })
      .where((e) => e.key.trim().isNotEmpty)
      .toList();

  final logoImage = logoBytes == null ? null : pw.MemoryImage(logoBytes);

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: fonts.base,
      bold: fonts.bold,
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => buildReportHeader(fonts: fonts, branding: branding, meta: meta, logoImage: logoImage),
      footer: (ctx) => buildReportFooter(fonts: fonts, context: ctx),
      build: (ctx) {
        final rows = fields.map((e) => <pw.Widget>[pw.Text(e.key), pw.Text(e.value)]).toList();
        return [
          zebraTable(
            fonts: fonts,
            headers: const ['Field', 'Value'],
            columnWidths: {
              0: const pw.FixedColumnWidth(160),
              1: const pw.FlexColumnWidth(),
            },
            rows: rows,
          ),
        ];
      },
    ),
  );

  return Uint8List.fromList(await doc.save());
}

Future<Uint8List?> _loadBytesFromPathOrUrl(String? pathOrUrl) async {
  final p = (pathOrUrl ?? '').trim();
  if (p.isEmpty) return null;

  if (p.startsWith('http://') || p.startsWith('https://')) {
    try {
      final resp = await http.get(Uri.parse(p));
      if (resp.statusCode == 200) return resp.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  if (!kIsWeb) {
    try {
      final file = io.File(p);
      if (await file.exists()) return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  try {
    return await ImageCacheService().getImage(p);
  } catch (_) {
    return null;
  }
}

pw.Widget buildReportHeader({
  required ReportFonts fonts,
  required ReportBranding? branding,
  required ReportMeta meta,
  pw.MemoryImage? logoImage,
}) {
  final small = pw.TextStyle(font: fonts.base, fontSize: 9, color: const PdfColor.fromInt(0xFF616161));
  final normal = pw.TextStyle(font: fonts.base, fontSize: 10, color: const PdfColor.fromInt(0xFF212121));
  final bold = pw.TextStyle(font: fonts.bold, fontSize: 12, color: const PdfColor.fromInt(0xFF212121));

  final left = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Logo removed as per requirements
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(branding?.companyName ?? 'Company', style: bold),
            if ((branding?.address ?? '').trim().isNotEmpty)
              pw.Text(branding!.address!.trim(), style: small, maxLines: 2),
            if ((branding?.contact ?? '').trim().isNotEmpty)
              pw.Text(branding!.contact!.trim(), style: small, maxLines: 1),
          ],
        ),
      ),
    ],
  );

  final right = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Text(meta.title, style: pw.TextStyle(font: fonts.bold, fontSize: 12)),
      pw.SizedBox(height: 4),
      pw.Text('Generated On: ${DateFormat('dd MMM yyyy, hh:mm a').format(meta.generatedAt.toLocal())}', style: small),
      pw.Text('Report Serial: ${meta.serialNumber}', style: normal),
    ],
  );

  return pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: left),
          pw.SizedBox(width: 12),
          right,
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Divider(color: const PdfColor.fromInt(0xFFBDBDBD)),
      pw.SizedBox(height: 8),
    ],
  );
}

pw.Widget buildReportFooter({required ReportFonts fonts, required pw.Context context}) {
  final small = pw.TextStyle(font: fonts.base, fontSize: 9, color: const PdfColor.fromInt(0xFF616161));
  return pw.Column(
    children: [
      pw.Divider(color: const PdfColor.fromInt(0xFFBDBDBD)),
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'This is a computer-generated report and does not require a physical signature.',
              style: small,
            ),
          ),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: small),
        ],
      ),
    ],
  );
}

pw.Widget zebraTable({
  required ReportFonts fonts,
  required List<String> headers,
  required List<List<pw.Widget>> rows,
  Map<int, pw.TableColumnWidth>? columnWidths,
  pw.EdgeInsets cellPadding = const pw.EdgeInsets.all(6),
}) {
  final headerStyle = pw.TextStyle(font: fonts.bold, fontSize: 10, color: const PdfColor.fromInt(0xFF212121));
  final cellStyle = pw.TextStyle(font: fonts.base, fontSize: 10, color: const PdfColor.fromInt(0xFF212121));

  return pw.Table(
    border: pw.TableBorder.all(width: 0.5, color: const PdfColor.fromInt(0xFFBDBDBD)),
    columnWidths: columnWidths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
        children: headers
            .map((h) => pw.Padding(padding: cellPadding, child: pw.Text(h, style: headerStyle)))
            .toList(),
      ),
      ...List.generate(rows.length, (i) {
        final bg = i.isOdd ? const PdfColor.fromInt(0xFFFAFAFA) : const PdfColor.fromInt(0xFFFFFFFF);
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: rows[i]
              .map((w) => pw.Padding(padding: cellPadding, child: pw.DefaultTextStyle(style: cellStyle, child: w)))
              .toList(),
        );
      }),
    ],
  );
}

Future<Uint8List> buildExpenseStatementPdf({
  required PdfPageFormat format,
  required AppDatabase db,
  required Map<String, dynamic>? currentUser,
  required String title,
  required List<ExpenditureModel> rows,
  required bool groupByCategory,
  required String action,
  String? serialNumber,
  DateTime? generatedAt,
  bool logHistory = true,
}) async {
  final baseFontBytes = (await _tryLoadRobotoBytes('assets/fonts/Roboto-Regular.ttf')) ?? Uint8List(0);
  final boldFontBytes = (await _tryLoadRobotoBytes('assets/fonts/Roboto-Bold.ttf')) ?? Uint8List(0);
  if (baseFontBytes.isEmpty || boldFontBytes.isEmpty) {
    // Fall back to in-isolate Helvetica if the assets aren't available
  }

  final branding = await loadReportBranding(db: db, currentUser: currentUser);
  final logoBytes = null; // Logo removed as per requirements
  final meta = ReportMeta(
    title: title,
    serialNumber: serialNumber ?? generateReportSerial(prefix: 'EXP'),
    generatedAt: generatedAt ?? DateTime.now(),
  );

  final pdfBytes = await compute(
    _buildExpenseStatementPdfInIsolate,
    {
      'format': {
        'width': format.width,
        'height': format.height,
        'marginLeft': format.marginLeft,
        'marginRight': format.marginRight,
        'marginTop': format.marginTop,
        'marginBottom': format.marginBottom,
      },
      'baseFontBytes': baseFontBytes,
      'boldFontBytes': boldFontBytes,
      'logoBytes': logoBytes,
      'branding': branding == null
          ? null
          : {
              'companyId': branding.companyId,
              'companyName': branding.companyName,
              'address': branding.address,
              'contact': branding.contact,
            },
      'title': title,
      'serialNumber': meta.serialNumber,
      'generatedAtIso': meta.generatedAt.toUtc().toIso8601String(),
      'groupByCategory': groupByCategory,
      'rows': rows.map((e) => e.toMap()).toList(),
    },
  );

  if (logHistory) {
    await logReportHistory(
      db: db,
      currentUser: currentUser,
      companyId: branding?.companyId,
      module: 'expenditure',
      entityId: null,
      reportType: title,
      action: action,
      serialNumber: meta.serialNumber,
      generatedAt: meta.generatedAt,
    );
  }

  return pdfBytes;
}

Future<Uint8List> buildTradingDealSummaryPdf({
  required PdfPageFormat format,
  required AppDatabase db,
  required Map<String, dynamic>? currentUser,
  required Map<String, dynamic> entry,
  required String action,
  String? serialNumber,
  DateTime? generatedAt,
  bool logHistory = true,
}) async {
  final baseFontBytes = (await _tryLoadRobotoBytes('assets/fonts/Roboto-Regular.ttf')) ?? Uint8List(0);
  final boldFontBytes = (await _tryLoadRobotoBytes('assets/fonts/Roboto-Bold.ttf')) ?? Uint8List(0);
  final branding = await loadReportBranding(db: db, currentUser: currentUser);
  final logoBytes = null; // Logo removed as per requirements

  final id = (entry['id'] ?? '').toString();
  final meta = ReportMeta(
    title: 'Deal Summary',
    serialNumber: serialNumber ?? generateReportSerial(prefix: 'DL'),
    generatedAt: generatedAt ?? DateTime.now(),
  );

  final pdfBytes = await compute(
    _buildTradingDealSummaryPdfInIsolate,
    {
      'format': {
        'width': format.width,
        'height': format.height,
        'marginLeft': format.marginLeft,
        'marginRight': format.marginRight,
        'marginTop': format.marginTop,
        'marginBottom': format.marginBottom,
      },
      'baseFontBytes': baseFontBytes,
      'boldFontBytes': boldFontBytes,
      'logoBytes': logoBytes,
      'branding': branding == null
          ? null
          : {
              'companyId': branding.companyId,
              'companyName': branding.companyName,
              'address': branding.address,
              'contact': branding.contact,
            },
      'title': meta.title,
      'serialNumber': meta.serialNumber,
      'generatedAtIso': meta.generatedAt.toUtc().toIso8601String(),
      'entry': _sanitizeMapForIsolate(Map<String, dynamic>.from(entry)),
    },
  );

  if (logHistory) {
    await logReportHistory(
      db: db,
      currentUser: currentUser,
      companyId: branding?.companyId,
      module: 'trading',
      entityId: id.isEmpty ? null : id,
      reportType: 'Deal Summary',
      action: action,
      serialNumber: meta.serialNumber,
      generatedAt: meta.generatedAt,
    );
  }

  return pdfBytes;
}

Future<Uint8List> buildPropertyCatalogPdf({
  required PdfPageFormat format,
  required AppDatabase db,
  required Map<String, dynamic>? currentUser,
  required Map<String, dynamic> propertyData,
  required Map<String, String> societyBlock,
  List<String>? imagePaths,
  required String action,
  String? serialNumber,
  DateTime? generatedAt,
  bool logHistory = true,
}) async {
  final baseFontBytes = (await _tryLoadRobotoBytes('assets/fonts/Roboto-Regular.ttf')) ?? Uint8List(0);
  final boldFontBytes = (await _tryLoadRobotoBytes('assets/fonts/Roboto-Bold.ttf')) ?? Uint8List(0);
  final branding = await loadReportBranding(db: db, currentUser: currentUser);
  final logoBytes = null; // Logo removed as per requirements

  final id = (propertyData['id'] ?? '').toString();
  final meta = ReportMeta(
    title: 'Property Catalog',
    serialNumber: serialNumber ?? generateReportSerial(prefix: 'INV'),
    generatedAt: generatedAt ?? DateTime.now(),
  );

  final imgs = (imagePaths ?? const []).where((e) => e.trim().isNotEmpty).take(3).toList();
  final imageBytes = <Uint8List?>[];
  for (var i = 0; i < 3; i++) {
    final path = i < imgs.length ? imgs[i] : null;
    if (path == null) {
      imageBytes.add(null);
      continue;
    }
    imageBytes.add(await _loadBytesFromPathOrUrl(path));
  }

  final pdfBytes = await compute(
    _buildPropertyCatalogPdfInIsolate,
    {
      'format': {
        'width': format.width,
        'height': format.height,
        'marginLeft': format.marginLeft,
        'marginRight': format.marginRight,
        'marginTop': format.marginTop,
        'marginBottom': format.marginBottom,
      },
      'baseFontBytes': baseFontBytes,
      'boldFontBytes': boldFontBytes,
      'logoBytes': logoBytes,
      'branding': branding == null
          ? null
          : {
              'companyId': branding.companyId,
              'companyName': branding.companyName,
              'address': branding.address,
              'contact': branding.contact,
            },
      'title': meta.title,
      'serialNumber': meta.serialNumber,
      'generatedAtIso': meta.generatedAt.toUtc().toIso8601String(),
      'propertyData': _sanitizeMapForIsolate(Map<String, dynamic>.from(propertyData)),
      'societyBlock': societyBlock,
      'imageBytes': imageBytes,
    },
  );

  if (logHistory) {
    await logReportHistory(
      db: db,
      currentUser: currentUser,
      companyId: branding?.companyId,
      module: 'inventory',
      entityId: id.isEmpty ? null : id,
      reportType: 'Property Catalog',
      action: action,
      serialNumber: meta.serialNumber,
      generatedAt: meta.generatedAt,
    );
  }

  return pdfBytes;
}

Future<Uint8List> buildKeyValueReportPdf({
  required PdfPageFormat format,
  required AppDatabase db,
  required Map<String, dynamic>? currentUser,
  required String module,
  required String? entityId,
  required String title,
  required String action,
  required List<MapEntry<String, String>> fields,
  String? serialNumber,
  DateTime? generatedAt,
  bool logHistory = true,
  // Optional pre-loaded data to prevent blocking
  Uint8List? preloadedBaseFontBytes,
  Uint8List? preloadedBoldFontBytes,
  ReportBranding? preloadedBranding,
}) async {
  // Use pre-loaded data if provided, otherwise load it (blocking)
  final baseFontBytes = preloadedBaseFontBytes ?? ((await _tryLoadRobotoBytes('assets/fonts/Roboto-Regular.ttf')) ?? Uint8List(0));
  final boldFontBytes = preloadedBoldFontBytes ?? ((await _tryLoadRobotoBytes('assets/fonts/Roboto-Bold.ttf')) ?? Uint8List(0));
  final branding = preloadedBranding ?? await loadReportBranding(db: db, currentUser: currentUser);
  final logoBytes = null; // Logo removed as per requirements

  final meta = ReportMeta(
    title: title,
    serialNumber: serialNumber ?? generateReportSerial(prefix: 'RPT'),
    generatedAt: generatedAt ?? DateTime.now(),
  );

  final pdfBytes = await compute(
    _buildKeyValueReportPdfInIsolate,
    {
      'format': {
        'width': format.width,
        'height': format.height,
        'marginLeft': format.marginLeft,
        'marginRight': format.marginRight,
        'marginTop': format.marginTop,
        'marginBottom': format.marginBottom,
      },
      'baseFontBytes': baseFontBytes,
      'boldFontBytes': boldFontBytes,
      'logoBytes': logoBytes,
      'branding': branding == null
          ? null
          : {
              'companyId': branding.companyId,
              'companyName': branding.companyName,
              'address': branding.address,
              'contact': branding.contact,
            },
      'title': title,
      'serialNumber': meta.serialNumber,
      'generatedAtIso': meta.generatedAt.toUtc().toIso8601String(),
      'fields': fields.map((e) => {'k': e.key, 'v': e.value}).toList(),
    },
  );

  if (logHistory) {
    await logReportHistory(
      db: db,
      currentUser: currentUser,
      companyId: branding?.companyId,
      module: module,
      entityId: entityId,
      reportType: title,
      action: action,
      serialNumber: meta.serialNumber,
      generatedAt: meta.generatedAt,
    );
  }

  return pdfBytes;
}

Future<void> savePdfBytesToDisk({
  required Uint8List pdfBytes,
  required String suggestedBaseName,
}) async {
  if (kIsWeb) {
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    return;
  }

  final os = io.Platform.operatingSystem;
  final isMobile = os == 'android' || os == 'ios';
  if (isMobile) {
    await Printing.sharePdf(bytes: pdfBytes, filename: '$suggestedBaseName.pdf');
    return;
  }

  final dir = await getDirectoryPath();
  if (dir == null) return;
  final path = '$dir${io.Platform.pathSeparator}$suggestedBaseName.pdf';
  await io.File(path).writeAsBytes(pdfBytes, flush: true);
}

Future<void> ensureReportHistoryTable(AppDatabase db) async {
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS report_history (
      id TEXT PRIMARY KEY,
      company_id TEXT,
      user_id TEXT,
      user_name TEXT,
      module TEXT,
      entity_id TEXT,
      report_type TEXT,
      action TEXT,
      serial_number TEXT,
      generated_at TEXT
    )
  ''');
}

Future<void> logReportHistory({
  required AppDatabase db,
  required Map<String, dynamic>? currentUser,
  required String? companyId,
  required String module,
  required String? entityId,
  required String reportType,
  required String action,
  required String serialNumber,
  required DateTime generatedAt,
}) async {
  try {
    await ensureReportHistoryTable(db);
  } catch (_) {}

  final id = DateTime.now().millisecondsSinceEpoch.toString();
  final uid = currentUser?['id']?.toString() ?? currentUser?['user_id']?.toString();
  final name = (currentUser?['name'] ?? currentUser?['username'] ?? uid ?? '').toString();
  final cid = companyId ?? RoleUtils.getUserCompanyId(currentUser);
  final nowIso = generatedAt.toUtc().toIso8601String();

  try {
    await db.customStatement(
      'INSERT OR REPLACE INTO report_history (id, company_id, user_id, user_name, module, entity_id, report_type, action, serial_number, generated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, cid, uid, name, module, entityId, reportType, action, serialNumber, nowIso],
    );
  } catch (_) {}

  if (Firebase.apps.isNotEmpty) {
    try {
      await FirebaseFirestore.instance.collection('report_history').doc(id).set(
        {
          'id': id,
          'companyId': cid,
          'userId': uid,
          'userName': name,
          'module': module,
          'entityId': entityId,
          'reportType': reportType,
          'action': action,
          'serialNumber': serialNumber,
          'generatedAt': nowIso,
          'createdAt': nowIso,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
