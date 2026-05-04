import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/metadata_template.dart';
import '../models/rename_convention.dart';

enum ImportItemKind {
  metadataTemplate,
  renameConvention,
  unknown,
}

class ImportPayload {
  const ImportPayload({
    required this.fileName,
    required this.rawJson,
    required this.kind,
    required this.sourcePath,
  });

  final String fileName;
  final Map<String, dynamic> rawJson;
  final ImportItemKind kind;
  final String sourcePath;
}

class ImportExportService {
  static const formatVersion = '1.0';

  Future<String?> chooseSavePath({
    required String dialogTitle,
    required String defaultFileName,
    required List<String> allowedExtensions,
  }) async {
    return FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      lockParentWindow: true,
    );
  }

  Future<List<String>> chooseImportFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['json', 'zip'],
      lockParentWindow: true,
    );

    if (result == null) {
      return const [];
    }

    return result.paths.whereType<String>().toList(growable: false);
  }

  Map<String, dynamic> templateExportJson(MetadataTemplate template) {
    return {
      'gledhillForgeVersion': formatVersion,
      'type': 'metadataTemplate',
      'name': template.name,
      'isFavorite': template.isFavorite,
      'fields': template.fields,
    };
  }

  Map<String, dynamic> renameExportJson(RenameConvention convention) {
    return {
      'gledhillForgeVersion': formatVersion,
      'type': 'renameConvention',
      'name': convention.name,
      'isFavorite': convention.isFavorite,
      'pattern': convention.pattern,
    };
  }

  Future<void> exportSingleJson({
    required Map<String, dynamic> payload,
    required String outputPath,
  }) async {
    final file = File(outputPath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  }

  Future<void> exportDirectoryAsZip({
    required Directory rootDirectory,
    required String relativeFolderPath,
    required String outputPath,
  }) async {
    final folderPath = relativeFolderPath.isEmpty
        ? rootDirectory.path
        : p.join(rootDirectory.path, relativeFolderPath);
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      throw StateError('Folder does not exist: $relativeFolderPath');
    }

    final archive = Archive();
    final entities = folder.listSync(recursive: true).whereType<File>();

    for (final file in entities) {
      if (!file.path.toLowerCase().endsWith('.json')) {
        continue;
      }

      final relative = p.relative(file.path, from: folder.path);
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    await File(outputPath).writeAsBytes(encoded);
  }

  Future<void> exportAllAsZip({
    required Directory rootDirectory,
    required String outputPath,
  }) async {
    final archive = Archive();
    final entities = rootDirectory.listSync(recursive: true).whereType<File>();

    for (final file in entities) {
      if (!file.path.toLowerCase().endsWith('.json')) {
        continue;
      }

      final relative = p.relative(file.path, from: rootDirectory.path);
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    await File(outputPath).writeAsBytes(encoded);
  }

  Future<List<ImportPayload>> loadImportPayloads(List<String> paths) async {
    final payloads = <ImportPayload>[];

    for (final path in paths) {
      final extension = p.extension(path).toLowerCase();
      if (extension == '.json') {
        final json = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
        payloads.add(
          ImportPayload(
            fileName: p.basename(path),
            rawJson: json,
            kind: detectKind(json),
            sourcePath: path,
          ),
        );
      } else if (extension == '.zip') {
        final bytes = await File(path).readAsBytes();
        payloads.addAll(_loadZipPayloads(bytes, sourcePath: path));
      }
    }

    return payloads;
  }

  List<ImportPayload> _loadZipPayloads(Uint8List bytes, {required String sourcePath}) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final payloads = <ImportPayload>[];

    for (final entry in archive) {
      if (!entry.isFile || !entry.name.toLowerCase().endsWith('.json')) {
        continue;
      }

      final data = entry.content;
      final entryBytes = data as List<int>;
      final json = jsonDecode(utf8.decode(entryBytes)) as Map<String, dynamic>;

      payloads.add(
        ImportPayload(
          fileName: p.basename(entry.name),
          rawJson: json,
          kind: detectKind(json),
          sourcePath: sourcePath,
        ),
      );
    }

    return payloads;
  }

  ImportItemKind detectKind(Map<String, dynamic> json) {
    final type = (json['type'] as String?)?.trim();
    if (type == 'metadataTemplate') {
      return ImportItemKind.metadataTemplate;
    }
    if (type == 'renameConvention') {
      return ImportItemKind.renameConvention;
    }

    if (json.containsKey('fields')) {
      return ImportItemKind.metadataTemplate;
    }
    if (json.containsKey('pattern')) {
      return ImportItemKind.renameConvention;
    }

    return ImportItemKind.unknown;
  }

  MetadataTemplate toTemplate(Map<String, dynamic> json) {
    return MetadataTemplate(
      id: (json['id'] as String?) ?? (json['name'] as String? ?? 'Imported Template'),
      name: (json['name'] as String? ?? 'Imported Template').trim(),
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      fields: Map<String, String>.from((json['fields'] as Map?) ?? const {}),
    );
  }

  RenameConvention toConvention(Map<String, dynamic> json) {
    return RenameConvention(
      id: (json['id'] as String?) ?? (json['name'] as String? ?? 'Imported Convention'),
      name: (json['name'] as String? ?? 'Imported Convention').trim(),
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      pattern: (json['pattern'] as String?) ?? '{year}-{month}-{day}_{sequence:3}',
    );
  }
}
