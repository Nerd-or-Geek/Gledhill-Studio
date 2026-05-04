import 'dart:io';

import 'package:exif/exif.dart';

import 'exiftool_service.dart';

class ExifReaderService {
  ExifReaderService({required ExifToolService exifToolService}) : _exifToolService = exifToolService;

  final ExifToolService _exifToolService;

  Future<Map<String, String>> readAllMetadata(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return const {'Status': 'File not found'};
    }

    try {
      final exiftoolMetadata = await _exifToolService.readMetadata(imagePath);
      if (exiftoolMetadata.isNotEmpty) {
        return exiftoolMetadata;
      }
    } catch (_) {
      // Fallback to basic EXIF parser below when ExifTool is unavailable.
    }

    final bytes = await file.readAsBytes();
    final tags = await readExifFromBytes(bytes);

    final result = <String, String>{};
    for (final entry in tags.entries) {
      result[entry.key] = entry.value.printable;
    }

    return result;
  }

  Future<Map<String, String>> readSummary(String imagePath) async {
    final tags = await readAllMetadata(imagePath);
    return buildSummary(tags);
  }

  Map<String, String> buildSummary(Map<String, String> tags) {
    String? read(String key) => tags[key];

    return {
      if (read('Image ImageDescription') != null) 'Title': read('Image ImageDescription')!,
      if (read('EXIF DateTimeOriginal') != null) 'Date': read('EXIF DateTimeOriginal')!,
      if (read('Image Artist') != null) 'Author': read('Image Artist')!,
      if (read('GPS GPSLatitude') != null && read('GPS GPSLongitude') != null)
        'GPS': '${read('GPS GPSLatitude')} / ${read('GPS GPSLongitude')}',
      'Tags': '${tags.length} found',
    };
  }
}
