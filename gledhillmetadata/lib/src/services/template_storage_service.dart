import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/metadata_template.dart';
import '../models/template_folder_node.dart';

class TemplateStorageService {
  static const _rootFolderName = 'metadata_templates';
  static const _defaultFolderName = 'Default';

  Future<Directory> _ensureRoot() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docsDir.path, _rootFolderName));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    final defaultDir = Directory(p.join(root.path, _defaultFolderName));
    if (!await defaultDir.exists()) {
      await defaultDir.create(recursive: true);
    }

    return root;
  }

  Future<Directory> ensureRootDirectory() async {
    return _ensureRoot();
  }

  Future<TemplateFolderNode> loadFolderTree() async {
    final root = await _ensureRoot();
    return _toTreeNode(root, root.path);
  }

  TemplateFolderNode _toTreeNode(Directory directory, String rootPath) {
    final relative = p.relative(directory.path, from: rootPath);
    final children =
        directory
            .listSync()
            .whereType<Directory>()
            .map((child) => _toTreeNode(child, rootPath))
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return TemplateFolderNode(
      name: p.basename(directory.path),
      relativePath: relative == '.' ? '' : relative,
      children: children,
    );
  }

  Future<List<MetadataTemplate>> loadTemplatesInFolder(
    String relativeFolderPath,
  ) async {
    final root = await _ensureRoot();
    final folderPath = relativeFolderPath.isEmpty
        ? p.join(root.path, _defaultFolderName)
        : p.join(root.path, relativeFolderPath);
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      return const [];
    }

    final templates = <MetadataTemplate>[];
    final files = folder.listSync().whereType<File>().where(
      (file) => file.path.toLowerCase().endsWith('.json'),
    );

    for (final file in files) {
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        templates.add(
          MetadataTemplate.fromJson(json).copyWith(
            id: p.basenameWithoutExtension(file.path),
            folderPath: relativeFolderPath,
          ),
        );
      } catch (_) {
        // Skip malformed template JSON files.
      }
    }

    templates.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return templates;
  }

  Future<void> saveTemplate({
    required String relativeFolderPath,
    required MetadataTemplate template,
    String? originalId,
  }) async {
    final root = await _ensureRoot();
    final folderPath = relativeFolderPath.isEmpty
        ? p.join(root.path, _defaultFolderName)
        : p.join(root.path, relativeFolderPath);
    final folder = Directory(folderPath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final fileName = '${_sanitizeFileName(template.name)}.json';
    final targetFile = File(p.join(folder.path, fileName));

    if (originalId != null && originalId != _sanitizeFileName(template.name)) {
      final previousFile = File(p.join(folder.path, '$originalId.json'));
      if (await previousFile.exists()) {
        await previousFile.delete();
      }
    }

    await targetFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(template.toJson()),
    );
  }

  Future<void> deleteTemplate({
    required String relativeFolderPath,
    required String templateId,
  }) async {
    final root = await _ensureRoot();
    final folderPath = relativeFolderPath.isEmpty
        ? p.join(root.path, _defaultFolderName)
        : p.join(root.path, relativeFolderPath);
    final file = File(p.join(folderPath, '$templateId.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> createFolder({
    required String parentRelativePath,
    required String folderName,
  }) async {
    final root = await _ensureRoot();
    final parentPath = parentRelativePath.isEmpty
        ? root.path
        : p.join(root.path, parentRelativePath);
    final folder = Directory(p.join(parentPath, folderName));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
  }

  Future<void> renameFolder({
    required String relativePath,
    required String newName,
  }) async {
    final root = await _ensureRoot();
    final original = Directory(p.join(root.path, relativePath));
    if (!await original.exists()) {
      return;
    }
    final parent = p.dirname(original.path);
    await original.rename(p.join(parent, newName));
  }

  Future<void> deleteFolder(String relativePath) async {
    final root = await _ensureRoot();
    final folder = Directory(p.join(root.path, relativePath));
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  Future<List<MetadataTemplate>> loadTemplates() async {
    return loadTemplatesInFolder('');
  }

  Future<List<MetadataTemplate>> loadAllTemplates() async {
    final root = await _ensureRoot();
    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.json'));

    final templates = <MetadataTemplate>[];
    for (final file in files) {
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final relativeFolder = p.dirname(
          p.relative(file.path, from: root.path),
        );
        templates.add(
          MetadataTemplate.fromJson(json).copyWith(
            id: p.basenameWithoutExtension(file.path),
            folderPath: relativeFolder == '.' ? '' : relativeFolder,
          ),
        );
      } catch (_) {
        // Skip malformed files.
      }
    }

    templates.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return templates;
  }

  Future<void> saveTemplates(List<MetadataTemplate> templates) async {
    for (final template in templates) {
      await saveTemplate(
        relativeFolderPath: template.folderPath,
        template: template,
      );
    }
  }

  String _sanitizeFileName(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' ', '_');
  }
}
