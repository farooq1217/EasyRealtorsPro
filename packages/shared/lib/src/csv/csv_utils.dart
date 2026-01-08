import 'package:csv/csv.dart';
import 'csv_models.dart';

class CsvUtils {
  static List<CsvExportRow> parseExportCsv(String csvContent) {
    final rows = const CsvToListConverter(eol: '\n').convert(csvContent);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((e) => e.toString()).toList();
    final list = <CsvExportRow>[];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      final map = <String, String>{};
      for (var j = 0; j < headers.length && j < r.length; j++) {
        map[headers[j]] = r[j]?.toString() ?? '';
      }
      final exportId = map['exportId'] ?? '';
      final module = map['module'] ?? '';
      final operation = map['operation'] ?? '';
      final id = map['id'] ?? '';
      final updatedAt = map['updatedAt'] ?? '';
      map.removeWhere((k, _) => const {
        'exportId', 'module', 'operation', 'id', 'updatedAt'
      }.contains(k));
      list.add(CsvExportRow(
        exportId: exportId,
        module: module,
        operation: operation,
        id: id,
        updatedAt: updatedAt,
        data: map,
      ));
    }
    return list;
  }

  static String writeExportCsv(List<CsvExportRow> rows) {
    final headers = <String>{
      'exportId', 'module', 'operation', 'id', 'updatedAt',
    };
    for (final r in rows) {
      headers.addAll(r.data.keys);
    }
    final headerList = headers.toList();
    final data = <List<dynamic>>[];
    data.add(headerList);
    for (final r in rows) {
      final row = <dynamic>[];
      for (final h in headerList) {
        switch (h) {
          case 'exportId': row.add(r.exportId); break;
          case 'module': row.add(r.module); break;
          case 'operation': row.add(r.operation); break;
          case 'id': row.add(r.id); break;
          case 'updatedAt': row.add(r.updatedAt); break;
          default: row.add(r.data[h] ?? '');
        }
      }
      data.add(row);
    }
    return const ListToCsvConverter().convert(data);
  }

  static List<BootstrapUserRow> parseBootstrapUsers(String csvContent) {
    final rows = const CsvToListConverter(eol: '\n').convert(csvContent);
    if (rows.length <= 1) return [];
    final header = rows.first.map((e) => e.toString()).toList();
    final uIdx = header.indexOf('username');
    final pIdx = header.indexOf('password');
    final out = <BootstrapUserRow>[];
    for (var i = 1; i < rows.length; i++) {
      final r = rows[i];
      final u = (uIdx >= 0 && uIdx < r.length) ? r[uIdx]?.toString() ?? '' : '';
      final p = (pIdx >= 0 && pIdx < r.length) ? r[pIdx]?.toString() ?? '' : '';
      if (u.isNotEmpty) out.add(BootstrapUserRow(u, p));
    }
    return out;
  }

  static String writeBootstrapUsers(List<BootstrapUserRow> rows) {
    final data = <List<dynamic>>[
      ['username', 'password']
    ];
    for (final r in rows) {
      data.add([r.username, r.password]);
    }
    return const ListToCsvConverter().convert(data);
  }
}
