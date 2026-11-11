// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'image_file_picker.dart';

Future<SelectedImageFile?> pickImageFileImpl() async {
  final completer = Completer<SelectedImageFile?>();
  final uploadInput = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp,.png,.jpg,.jpeg,.webp';

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
          completer.complete(SelectedImageFile(name: file.name, bytes: result));
        }
      } else if (result is ByteBuffer) {
        if (!completer.isCompleted) {
          completer.complete(
            SelectedImageFile(name: file.name, bytes: result.asUint8List()),
          );
        }
      } else if (result is List<int>) {
        if (!completer.isCompleted) {
          completer.complete(
            SelectedImageFile(name: file.name, bytes: result),
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

