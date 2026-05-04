import 'package:file_picker/file_picker.dart';

class FileSelectionService {
  Future<List<String>> pickPhotoPaths() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic', 'tif', 'tiff', 'webp'],
    );

    if (result == null) {
      return const [];
    }

    return result.paths.whereType<String>().toList(growable: false);
  }
}
