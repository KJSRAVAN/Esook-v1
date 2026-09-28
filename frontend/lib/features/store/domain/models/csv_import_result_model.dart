/// Model representing a single row-level error encountered during CSV bulk import.
class CsvRowErrorModel {
  final int? row;
  final String message;
  final String? field;

  const CsvRowErrorModel({
    this.row,
    required this.message,
    this.field,
  });

  factory CsvRowErrorModel.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      final rowVal = json['row'] ?? json['line'] ?? json['rowNumber'] ?? json['rowIndex'];
      final int? row = rowVal is int
          ? rowVal
          : rowVal is num
              ? rowVal.toInt()
              : int.tryParse(rowVal?.toString() ?? '');

      final message = json['message'] as String? ??
          json['error'] as String? ??
          json['reason'] as String? ??
          json['detail'] as String? ??
          json.toString();

      final field = json['field'] as String? ??
          json['column'] as String? ??
          json['property'] as String?;

      return CsvRowErrorModel(row: row, message: message, field: field);
    } else {
      final str = json.toString();
      final match = RegExp(r'row\s*(\d+)[:\s-]*(.*)', caseSensitive: false).firstMatch(str);
      if (match != null) {
        final rowNum = int.tryParse(match.group(1)!);
        final rawMsg = match.group(2)!.trim();
        return CsvRowErrorModel(
          row: rowNum,
          message: rawMsg.isNotEmpty ? rawMsg : str,
        );
      }
      return CsvRowErrorModel(message: str);
    }
  }

  Map<String, dynamic> toJson() => {
    if (row != null) 'row': row,
    'message': message,
    if (field != null) 'field': field,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CsvRowErrorModel &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          message == other.message &&
          field == other.field;

  @override
  int get hashCode => row.hashCode ^ message.hashCode ^ field.hashCode;

  @override
  String toString() =>
      'CsvRowErrorModel(row: $row, message: $message, field: $field)';
}

/// Model representing the response summary of a CSV bulk import operation.
///
/// Returned by `POST /stores/:storeId/items/import-csv`.
class CsvImportResultModel {
  final int imported;
  final int updated;
  final int skipped;
  final List<CsvRowErrorModel> errors;

  const CsvImportResultModel({
    this.imported = 0,
    this.updated = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  int get totalProcessed => imported + updated + skipped + errors.length;
  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => errors.isEmpty && (imported > 0 || updated > 0);

  factory CsvImportResultModel.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const CsvImportResultModel();
    }

    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    int parseCount(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is List) return value.length;
      return 0;
    }

    final imported = parseCount(
      data['imported'] ?? data['created'] ?? data['inserted'] ?? data['newItems'],
    );
    final updated = parseCount(
      data['updated'] ?? data['modified'] ?? data['updatedItems'],
    );
    final skipped = parseCount(
      data['skipped'] ?? data['ignored'] ?? data['skippedItems'],
    );

    final rawErrors = data['errors'] ??
        data['rowErrors'] ??
        data['failures'] ??
        data['itemErrors'];

    final List<CsvRowErrorModel> parsedErrors = [];
    if (rawErrors is List) {
      for (final e in rawErrors) {
        parsedErrors.add(CsvRowErrorModel.fromJson(e));
      }
    }

    return CsvImportResultModel(
      imported: imported,
      updated: updated,
      skipped: skipped,
      errors: parsedErrors,
    );
  }

  Map<String, dynamic> toJson() => {
    'imported': imported,
    'updated': updated,
    'skipped': skipped,
    'errors': errors.map((e) => e.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CsvImportResultModel &&
          runtimeType == other.runtimeType &&
          imported == other.imported &&
          updated == other.updated &&
          skipped == other.skipped &&
          errors.length == other.errors.length;

  @override
  int get hashCode =>
      imported.hashCode ^ updated.hashCode ^ skipped.hashCode ^ errors.length.hashCode;

  @override
  String toString() =>
      'CsvImportResultModel(imported: $imported, updated: $updated, skipped: $skipped, errors: ${errors.length})';
}
