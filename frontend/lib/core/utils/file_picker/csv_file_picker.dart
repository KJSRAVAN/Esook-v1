import 'csv_file_picker_stub.dart'
    if (dart.library.html) 'csv_file_picker_web.dart';
import '../../../features/admin/presentation/widgets/admin_csv_import_dialog.dart';

/// Opens the browser or platform native file picker to select a `.csv` file.
/// Returns a [SelectedCsvFile] with file name and raw bytes, or null if cancelled/unsupported.
Future<SelectedCsvFile?> pickCsvFile() => pickCsvFileImpl();
