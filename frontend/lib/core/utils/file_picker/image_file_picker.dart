import 'image_file_picker_stub.dart'
    if (dart.library.html) 'image_file_picker_web.dart';

/// Representation of a picked image file with its filename and raw bytes.
class SelectedImageFile {
  final String name;
  final List<int> bytes;

  const SelectedImageFile({
    required this.name,
    required this.bytes,
  });
}

/// Opens the platform file picker to select an image file (.jpg, .jpeg, .png, .webp).
/// Returns a [SelectedImageFile] or null if cancelled / unsupported.
Future<SelectedImageFile?> pickImageFile() => pickImageFileImpl();

