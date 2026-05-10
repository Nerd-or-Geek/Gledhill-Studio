import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../application/template_library_controller.dart';
import '../../../models/metadata_template.dart';
import '../../../models/template_folder_node.dart';
import '../../../services/import_export_service.dart';
import '../../../state/providers.dart';

enum _ImportConflictAction { replace, keepBoth, cancel }

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(templateLibraryControllerProvider);
    final controller = ref.read(templateLibraryControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
        actions: [
          TextButton.icon(
            onPressed: () => _importTemplates(context, ref, controller, state.selectedFolderPath),
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Import'),
          ),
          TextButton.icon(
            onPressed: () => _exportAll(context, ref),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Export All'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 320,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                            child: Row(
                              children: [
                                Icon(Icons.account_tree_outlined,
                                    size: 18, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('Folder Structure', style: Theme.of(context).textTheme.titleSmall),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  state.selectedFolderPath.isEmpty
                                      ? 'Selected: Root'
                                      : 'Selected: ${state.selectedFolderPath}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          _FolderToolbar(
                            onCreate: () => _createFolder(context, controller, state.selectedFolderPath),
                            onRename: () => _renameFolder(context, controller, state.selectedFolderPath),
                            onDelete: state.selectedFolderPath.isEmpty
                                ? null
                                : () => _deleteFolder(context, controller, state.selectedFolderPath),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: state.folderTree == null
                                ? const Center(child: Text('No folders found.'))
                                : ListView(
                                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                                    children: [
                                      _FolderTreeNode(
                                        node: state.folderTree!,
                                        selectedPath: state.selectedFolderPath,
                                        onSelect: controller.selectFolder,
                                        onExportFolder: (folderPath) => _exportFolder(context, ref, folderPath),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SearchBar(
                                hintText: 'Search templates',
                                leading: const Icon(Icons.search),
                                onChanged: controller.setSearchQuery,
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: () => _openTemplateEditor(context, ref, controller),
                              icon: const Icon(Icons.add),
                              label: const Text('New Template'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: state.filteredTemplates.isEmpty
                              ? const Center(child: Text('No templates in this folder.'))
                              : ListView.separated(
                                  itemCount: state.filteredTemplates.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final template = state.filteredTemplates[index];
                                    return _TemplateRow(
                                      template: template,
                                      onToggleFavorite: () => controller.saveTemplate(
                                        template.copyWith(isFavorite: !template.isFavorite),
                                        originalId: template.id,
                                      ).then((_) => ref.read(libraryCatalogControllerProvider.notifier).refresh()),
                                      onEdit: () => _openTemplateEditor(
                                        context,
                                        ref,
                                        controller,
                                        existing: template,
                                      ),
                                      onDuplicate: () => _duplicateTemplate(context, ref, controller, template),
                                      onExport: () => _exportSingleTemplate(context, ref, template),
                                      onDelete: () async {
                                        // Clear default if this template is the default
                                        if (ref.read(appSettingsControllerProvider).defaultTemplateId == template.id) {
                                          await ref.read(appSettingsControllerProvider.notifier).setDefaultTemplateId(null);
                                        }
                                        await controller.deleteTemplate(template);
                                        await ref.read(libraryCatalogControllerProvider.notifier).refresh();
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _duplicateTemplate(
    BuildContext context,
    WidgetRef ref,
    TemplateLibraryController controller,
    MetadataTemplate original,
  ) async {
    final duplicateName = 'Copy of ${original.name}';
    final duplicate = original.copyWith(
      id: duplicateName,
      name: duplicateName,
      isFavorite: false,
    );

    await controller.saveTemplate(duplicate);
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();

    MetadataTemplate target = duplicate;
    for (final item in ref.read(templateLibraryControllerProvider).templates) {
      if (item.name == duplicateName) {
        target = item;
        break;
      }
    }

    if (!context.mounted) {
      return;
    }

    await _openTemplateEditor(context, ref, controller, existing: target);
  }

  Future<void> _exportSingleTemplate(
    BuildContext context,
    WidgetRef ref,
    MetadataTemplate template,
  ) async {
    final service = ref.read(importExportServiceProvider);
    final path = await service.chooseSavePath(
      dialogTitle: 'Export template',
      defaultFileName: '${template.name}.json',
      allowedExtensions: const ['json'],
    );

    if (path == null) {
      return;
    }

    await service.exportSingleJson(
      payload: service.templateExportJson(template),
      outputPath: path,
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template exported: ${p.basename(path)}')),
    );
  }

  Future<void> _exportFolder(BuildContext context, WidgetRef ref, String folderPath) async {
    final service = ref.read(importExportServiceProvider);
    final storage = ref.read(templateStorageServiceProvider);
    final savePath = await service.chooseSavePath(
      dialogTitle: 'Export folder',
      defaultFileName: '${folderPath.isEmpty ? 'templates' : p.basename(folderPath)}.zip',
      allowedExtensions: const ['zip'],
    );

    if (savePath == null) {
      return;
    }

    final root = await storage.ensureRootDirectory();
    await service.exportDirectoryAsZip(
      rootDirectory: root,
      relativeFolderPath: folderPath,
      outputPath: savePath,
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder exported: ${p.basename(savePath)}')),
    );
  }

  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    final service = ref.read(importExportServiceProvider);
    final storage = ref.read(templateStorageServiceProvider);

    final savePath = await service.chooseSavePath(
      dialogTitle: 'Export all templates',
      defaultFileName: 'all_templates.zip',
      allowedExtensions: const ['zip'],
    );

    if (savePath == null) {
      return;
    }

    final root = await storage.ensureRootDirectory();
    await service.exportAllAsZip(rootDirectory: root, outputPath: savePath);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('All templates exported: ${p.basename(savePath)}')),
    );
  }

  Future<void> _importTemplates(
    BuildContext context,
    WidgetRef ref,
    TemplateLibraryController controller,
    String selectedFolder,
  ) async {
    final service = ref.read(importExportServiceProvider);
    final paths = await service.chooseImportFiles();
    if (paths.isEmpty) {
      return;
    }

    final payloads = await service.loadImportPayloads(paths);
    final templatePayloads = payloads.where((p) => p.kind == ImportItemKind.metadataTemplate).toList();
    final invalidCount = payloads.length - templatePayloads.length;

    final targetFolder = selectedFolder.isEmpty ? 'Imported' : selectedFolder;
    if (selectedFolder.isEmpty) {
      await controller.createFolder(parentRelativePath: '', folderName: 'Imported');
    }

    await controller.selectFolder(targetFolder);

    var importedCount = 0;
    final current = [...ref.read(templateLibraryControllerProvider).templates];

    for (final payload in templatePayloads) {
      var incoming = service.toTemplate(payload.rawJson).copyWith(isFavorite: false);

      MetadataTemplate? existing;
      for (final item in current) {
        if (item.name.toLowerCase() == incoming.name.toLowerCase()) {
          existing = item;
          break;
        }
      }

      if (existing != null) {
        if (!context.mounted) {
          return;
        }
        final action = await _askImportConflict(context, incoming.name, itemLabel: 'template');
        if (action == _ImportConflictAction.cancel) {
          continue;
        }
        if (action == _ImportConflictAction.keepBoth) {
          incoming = incoming.copyWith(name: _resolveImportedName(incoming.name, current.map((e) => e.name).toSet()));
          await controller.saveTemplate(incoming);
          current.add(incoming);
          importedCount++;
        } else {
          await controller.saveTemplate(incoming, originalId: existing.id);
          current.removeWhere((e) => e.id == existing!.id);
          current.add(incoming);
          importedCount++;
        }
      } else {
        await controller.saveTemplate(incoming);
        current.add(incoming);
        importedCount++;
      }
    }

    await ref.read(libraryCatalogControllerProvider.notifier).refresh();

    if (!context.mounted) {
      return;
    }

    final invalidSuffix = invalidCount > 0 ? ' ($invalidCount file(s) skipped: wrong type)' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$importedCount templates imported successfully$invalidSuffix')),
    );
  }

  Future<void> _createFolder(
    BuildContext context,
    TemplateLibraryController controller,
    String parentRelativePath,
  ) async {
    final input = await _askText(context, 'Create Folder', 'Folder name');
    if (input == null || input.isEmpty) {
      return;
    }

    await controller.createFolder(parentRelativePath: parentRelativePath, folderName: input);
  }

  Future<void> _renameFolder(
    BuildContext context,
    TemplateLibraryController controller,
    String relativePath,
  ) async {
    if (relativePath.isEmpty) {
      return;
    }

    final input = await _askText(context, 'Rename Folder', 'New folder name');
    if (input == null || input.isEmpty) {
      return;
    }

    await controller.renameFolder(relativePath: relativePath, newName: input);
  }

  Future<void> _deleteFolder(
    BuildContext context,
    TemplateLibraryController controller,
    String relativePath,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text('Delete folder "$relativePath" and all templates inside it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.deleteFolder(relativePath);
    }
  }

  Future<void> _openTemplateEditor(
    BuildContext context,
    WidgetRef ref,
    TemplateLibraryController controller, {
    MetadataTemplate? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final selectedFields = <String>{...existing?.fields.keys ?? const <String>{}};
    final fieldValues = <String, String>{...existing?.fields ?? const <String, String>{}};

    final metadataFields = <String, List<String>>{
      'XMP': [
        'XMP.Title',
        'XMP.Description',
        'XMP.Keywords',
        'XMP.Headline',
        'XMP.Creator',
        'XMP.Copyright',
        'XMP.CreatorContactInfo',
      ],
      'EXIF': [
        'EXIF.DateTimeOriginal',
        'EXIF.ISO',
        'EXIF.FNumber',
        'EXIF.FocalLength',
        'EXIF.Make',
        'EXIF.Model',
        'EXIF.LensModel',
        'EXIF.ExposureTime',
        'EXIF.Flash',
        'EXIF.WhiteBalance',
      ],
      'IPTC': [
        'IPTC.Headline',
        'IPTC.Keywords',
        'IPTC.Caption',
        'IPTC.CopyrightNotice',
        'IPTC.Creator',
        'IPTC.CreatorJobTitle',
      ],
    };

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(existing == null ? 'Create Template' : 'Edit Template'),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Template name'),
                      ),
                      const SizedBox(height: 12),
                      for (final group in metadataFields.entries) ...[
                        Text(group.key, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        for (final field in group.value)
                          Column(
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(field),
                                value: selectedFields.contains(field),
                                onChanged: (value) {
                                  setModalState(() {
                                    if (value == true) {
                                      selectedFields.add(field);
                                    } else {
                                      selectedFields.remove(field);
                                    }
                                  });
                                },
                              ),
                              if (selectedFields.contains(field))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: '$field value (leave empty to preserve existing)',
                                      border: const OutlineInputBorder(),
                                    ),
                                    controller: TextEditingController(
                                      text: fieldValues[field] ?? '',
                                    ),
                                    onChanged: (value) => fieldValues[field] = value,
                                  ),
                                ),
                            ],
                          ),
                        const Divider(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (saved != true || nameController.text.trim().isEmpty) {
      return;
    }

    final fields = <String, String>{
      for (final field in selectedFields) field: fieldValues[field] ?? '',
    };

    await controller.saveTemplate(
      MetadataTemplate(
        id: existing?.id ?? nameController.text.trim(),
        name: nameController.text.trim(),
        isFavorite: existing?.isFavorite ?? false,
        folderPath: existing?.folderPath ?? '',
        fields: fields,
      ),
      originalId: existing?.id,
    );
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
  }

  Future<String?> _askText(BuildContext context, String title, String label) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _FolderToolbar extends StatelessWidget {
  const _FolderToolbar({
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  final VoidCallback onCreate;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.create_new_folder, size: 18),
            label: const Text('Create'),
          ),
          OutlinedButton.icon(
            onPressed: onRename,
            icon: const Icon(Icons.drive_file_rename_outline, size: 18),
            label: const Text('Rename'),
          ),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _FolderTreeNode extends StatelessWidget {
  const _FolderTreeNode({
    required this.node,
    required this.selectedPath,
    required this.onSelect,
    required this.onExportFolder,
  });

  final TemplateFolderNode node;
  final String selectedPath;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onExportFolder;

  @override
  Widget build(BuildContext context) {
    final isSelected = node.relativePath == selectedPath;
    final colorScheme = Theme.of(context).colorScheme;
    final hasChildren = node.children.isNotEmpty;
    final folderIcon = hasChildren ? Icons.folder_open_outlined : Icons.folder_outlined;

    return ExpansionTile(
      initiallyExpanded: isSelected,
      iconColor: colorScheme.primary,
      collapsedIconColor: colorScheme.onSurfaceVariant,
      title: Row(
        children: [
          Icon(folderIcon, size: 18, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onSelect(node.relativePath),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Text(
                  node.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colorScheme.primary : null,
                  ),
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Folder actions',
            onSelected: (value) {
              if (value == 'export') {
                onExportFolder(node.relativePath);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('Export folder')),
            ],
          ),
        ],
      ),
      children: [
        for (final child in node.children)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _FolderTreeNode(
              node: child,
              selectedPath: selectedPath,
              onSelect: onSelect,
              onExportFolder: onExportFolder,
            ),
          ),
      ],
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDuplicate,
    required this.onExport,
    required this.onDelete,
  });

  final MetadataTemplate template;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: InkWell(
        onTap: onEdit,
        child: Text(template.name),
      ),
      subtitle: Text('${template.fields.length} fields configured'),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            onPressed: onToggleFavorite,
            icon: Icon(template.isFavorite ? Icons.star : Icons.star_border),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'duplicate') {
                onDuplicate();
              } else if (value == 'export') {
                onExport();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              PopupMenuItem(value: 'export', child: Text('Export')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

Future<_ImportConflictAction> _askImportConflict(
  BuildContext context,
  String name, {
  required String itemLabel,
}) async {
  final action = await showDialog<_ImportConflictAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$itemLabel already exists'),
      content: Text(
        'A $itemLabel named "$name" already exists. Replace it, keep both, or cancel?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _ImportConflictAction.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ImportConflictAction.keepBoth),
          child: const Text('Keep both'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ImportConflictAction.replace),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  return action ?? _ImportConflictAction.cancel;
}

String _resolveImportedName(String baseName, Set<String> existingNames) {
  var candidate = '$baseName imported';
  var i = 2;
  while (existingNames.any((name) => name.toLowerCase() == candidate.toLowerCase())) {
    candidate = '$baseName imported $i';
    i++;
  }
  return candidate;
}
