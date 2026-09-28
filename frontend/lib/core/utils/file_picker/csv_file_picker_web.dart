// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import '../../../features/admin/presentation/widgets/admin_csv_import_dialog.dart';

Future<SelectedCsvFile?> pickCsvFileImpl() async {
  final completer = Completer<SelectedCsvFile?>();
  final uploadInput = html.FileUploadInputElement()
    ..accept = '.csv,text/csv';

  uploadInput.onChange.listen((event) {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((event) {
      final result = reader.result;
      if (result is Uint8List) {
        if (!completer.isCompleted) {
          completer.complete(SelectedCsvFile(name: file.name, bytes: result));
        }
      } else if (result is ByteBuffer) {
        if (!completer.isCompleted) {
          completer.complete(
            SelectedCsvFile(name: file.name, bytes: result.asUint8List()),
          );
        }
      } else if (result is List<int>) {
        if (!completer.isCompleted) {
          completer.complete(
            SelectedCsvFile(name: file.name, bytes: result),
          );
        }
      } else if (result is String) {
        if (!completer.isCompleted) {
          completer.complete(
            SelectedCsvFile.fromString(name: file.name, content: result),
          );
        }
      } else {
        if (!completer.isCompleted) completer.complete(null);
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsArrayBuffer(file);
  });

  uploadInput.click();
  return completer.future;
}
