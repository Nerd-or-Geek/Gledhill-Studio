import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../features/settings/application/app_settings_controller.dart';
import '../models/metadata_template.dart';
import '../models/photo_item.dart';
import '../models/rename_convention.dart';
import '../utils/rename_pattern.dart';
import 'exiftool_service.dart';

class BatchApplyProgress {
  const BatchApplyProgress({
    required this.current,
    required this.total,
    required this.filePath,
  });

  final int current;
  final int total;
  final String filePath;
}

class BatchApplyResult {
  const BatchApplyResult({
    required this.processed,
    required this.undoLogPath,
    required this.updatedPaths,
    required this.pathMappings,
    required this.renamedCount,
    required this.metadataWrittenCount,
    this.errors = const [],
  });

  final int processed;
  final String undoLogPath;
  final List<String> updatedPaths;
  final Map<String, String> pathMappings;
  final int renamedCount;
  final int metadataWrittenCount;
  final List<String> errors;
}

class BatchApplyService {
  BatchApplyService({required ExifToolService exifToolService})
    : _exifToolService = exifToolService;

  final ExifToolService _exifToolService;

  Future<BatchApplyResult> apply({
    required List<PhotoItem> photos,
    required MetadataTemplate template,
    required RenameConvention convention,
    required MetadataMergeStrategy mergeStrategy,
    Future<void> Function(BatchApplyProgress progress)? onProgress,
  }) async {
    final errors = <String>[];
    final operations = <Map<String, dynamic>>[];
    final updatedPaths = <String>[];
    final pathMappings = <String, String>{};
    var renamedCount = 0;
    var metadataWrittenCount = 0;

    var metadataEngineAvailable = true;
    try {
      await _exifToolService.ensureBinaryReady();
    } catch (error) {
      metadataEngineAvailable = false;
      errors.add(
        'Metadata engine unavailable. Renames will proceed, metadata writes skipped: $error',
      );
    }

    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final sourceFile = File(photo.path);
      if (!await sourceFile.exists()) {
        errors.add('File not found: ${photo.path}');
        continue;
      }

      if (onProgress != null) {
        await onProgress(
          BatchApplyProgress(
            current: i + 1,
            total: photos.length,
            filePath: photo.path,
          ),
        );
      }

      if (metadataEngineAvailable) {
        try {
          final metadataResult = await _exifToolService.writeMetadata(
            filePath: photo.path,
            templateFields: template.fields,
            mergeStrategy: mergeStrategy,
          );
          if (metadataResult.successfulTagWrites > 0) {
            metadataWrittenCount++;
          }
          errors.addAll(metadataResult.warnings);
        } catch (error) {
          errors.add('Metadata write failed for ${photo.fileName}: $error');
        }
      }

      final effectiveMetadata = _metadataAfterTemplate(
        originalMetadata: photo.fullMetadata,
        templateFields: template.fields,
        mergeStrategy: mergeStrategy,
      );
      final ext = p.extension(photo.fileName);
      final title =
          _firstMetadataValue(effectiveMetadata, const [
            'XMP.Title',
            'Title',
          ]) ??
          photo.metadataSummary['Title'] ??
          p.basenameWithoutExtension(photo.fileName);
      var targetName = applyRenamePattern(
        pattern: convention.pattern,
        date: DateTime.now(),
        sequence: i + 1,
        title: title,
        metadata: effectiveMetadata,
        extension: ext,
      );

      var targetPath = p.join(p.dirname(photo.path), targetName);
      var suffix = 1;
      while (await File(targetPath).exists() &&
          p.normalize(targetPath) != p.normalize(photo.path)) {
        targetName = '${p.basenameWithoutExtension(targetName)}_$suffix$ext';
        targetPath = p.join(p.dirname(photo.path), targetName);
        suffix++;
      }

      if (p.normalize(targetPath) != p.normalize(photo.path)) {
        try {
          await sourceFile.rename(targetPath);
          renamedCount++;
        } catch (error) {
          errors.add('Rename failed for ${photo.fileName}: $error');
          targetPath = photo.path;
        }
      }

      operations.add({'originalPath': photo.path, 'newPath': targetPath});
      updatedPaths.add(targetPath);
      pathMappings[photo.path] = targetPath;
    }

    final logFile = await _writeUndoLog(
      operations: operations,
      template: template,
      convention: convention,
    );

    return BatchApplyResult(
      processed: operations.length,
      undoLogPath: logFile.path,
      updatedPaths: updatedPaths,
      pathMappings: pathMappings,
      renamedCount: renamedCount,
      metadataWrittenCount: metadataWrittenCount,
      errors: errors,
    );
  }

  Future<int> undoLastApply() async {
    final logFile = await _lastUndoLog();
    if (logFile == null || !await logFile.exists()) {
      return 0;
    }

    final payload =
        jsonDecode(await logFile.readAsString()) as Map<String, dynamic>;
    final operations = (payload['operations'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    var undone = 0;
    for (final operation in operations.reversed) {
      final from = File(operation['newPath'] as String);
      final toPath = operation['originalPath'] as String;
      if (await from.exists()) {
        await from.rename(toPath);
        undone++;
      }
    }

    return undone;
  }

  Future<File> _writeUndoLog({
    required List<Map<String, dynamic>> operations,
    required MetadataTemplate template,
    required RenameConvention convention,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final logDir = Directory(p.join(docsDir.path, 'apply_logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final file = File(p.join(logDir.path, 'last_apply.json'));

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'timestampUtc': now,
        'template': template.name,
        'convention': convention.name,
        'operations': operations,
      }),
    );

    return file;
  }

  Future<File?> _lastUndoLog() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(docsDir.path, 'apply_logs', 'last_apply.json'));
    if (!await file.exists()) {
      return null;
    }
    return file;
  }

  Map<String, String> _metadataAfterTemplate({
    required Map<String, String> originalMetadata,
    required Map<String, String> templateFields,
    required MetadataMergeStrategy mergeStrategy,
  }) {
    final output = mergeStrategy == MetadataMergeStrategy.replaceAll
        ? <String, String>{}
        : <String, String>{...originalMetadata};

    for (final entry in templateFields.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        continue;
      }

      final key = entry.key.trim();
      output[key] = value;
      final shortKey = key.contains('.') ? key.split('.').last : key;
      output[shortKey] = value;
      output[key.replaceAll('.', ' ')] = value;

      final normalizedShortKey = shortKey.toLowerCase();
      if (normalizedShortKey == 'creator') {
        output['author'] = value;
        output['creator'] = value;
      } else if (normalizedShortKey == 'headline') {
        output['headline'] = value;
      } else if (normalizedShortKey == 'description' ||
          normalizedShortKey == 'caption') {
        output['description'] = value;
      } else if (normalizedShortKey == 'keywords' ||
          normalizedShortKey == 'subject') {
        output['keywords'] = value;
      } else if (normalizedShortKey == 'copyright' ||
          normalizedShortKey == 'copyrightnotice') {
        output['copyright'] = value;
      }
    }

    return output;
  }

  String? _firstMetadataValue(Map<String, String> metadata, List<String> keys) {
    for (final key in keys) {
      final direct = metadata[key];
      if (direct != null && direct.trim().isNotEmpty) {
        return direct;
      }
      for (final entry in metadata.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase() &&
            entry.value.trim().isNotEmpty) {
          return entry.value;
        }
      }
    }
    return null;
  }
}
