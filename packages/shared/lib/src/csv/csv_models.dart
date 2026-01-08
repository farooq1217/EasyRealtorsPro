class CsvExportRow {
  final String exportId;
  final String module;
  final String operation;
  final String id;
  final String updatedAt;
  final Map<String, String> data;

  CsvExportRow({
    required this.exportId,
    required this.module,
    required this.operation,
    required this.id,
    required this.updatedAt,
    required this.data,
  });
}

class BootstrapUserRow {
  final String username;
  final String password;
  BootstrapUserRow(this.username, this.password);
}

class CsvUtils {
  static String writeExportCsv(List<CsvExportRow> rows) {
    final buffer = StringBuffer();
    // Header
    buffer.writeln('exportId,module,operation,id,updatedAt,data');
    for (final r in rows) {
      final dataJson = _escape(_mapToJson(r.data));
      buffer.writeln('${_escape(r.exportId)},${_escape(r.module)},${_escape(r.operation)},${_escape(r.id)},${_escape(r.updatedAt)},$dataJson');
    }
    return buffer.toString();
  }

  static String _escape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      final escaped = s.replaceAll('"', '""');
      return '"$escaped"';
    }
    return s;
  }

  static String _mapToJson(Map<String, String> m) {
    final entries = m.entries.map((e) => '"${_jsonEscape(e.key)}":"${_jsonEscape(e.value)}"').join(',');
    return '{'+entries+'}';
  }

  static String _jsonEscape(String s) => s
      .replaceAll('\\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
}
