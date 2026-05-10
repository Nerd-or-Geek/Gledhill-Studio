import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../models/metadata_template.dart';
import '../../../models/rename_convention.dart';
import '../../../services/import_export_service.dart';
import '../../../state/providers.dart';
import '../../../utils/rename_pattern.dart';
import '../../rename/application/rename_library_controller.dart';
import '../../templates/application/template_library_controller.dart';

enum _WorkflowKind { metadata, rename }

enum _LibraryAction { edit, duplicate, export, setDefault, delete }

enum _ImportConflictAction { replace, keepBoth, cancel }

class WorkflowLibraryScreen extends ConsumerStatefulWidget {
  const WorkflowLibraryScreen({super.key});

  @override
  ConsumerState<WorkflowLibraryScreen> createState() =>
      _WorkflowLibraryScreenState();
}

class _WorkflowLibraryScreenState extends ConsumerState<WorkflowLibraryScreen> {
  _WorkflowKind _kind = _WorkflowKind.metadata;
  bool _showFavoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final templateState = ref.watch(templateLibraryControllerProvider);
    final renameState = ref.watch(renameLibraryControllerProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final isLoading = _kind == _WorkflowKind.metadata
        ? templateState.isLoading
        : renameState.isLoading;

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _WorkflowLibraryPane(
              kind: _kind,
              templateState: templateState,
              renameState: renameState,
              showFavoritesOnly: _showFavoritesOnly,
              defaultTemplateId: settings.defaultTemplateId,
              defaultConventionId: settings.defaultConventionId,
              onKindChanged: (kind) => setState(() => _kind = kind),
              onFavoritesOnlyChanged: (value) =>
                  setState(() => _showFavoritesOnly = value),
              onSearchChanged: _setSearchQuery,
              onCreate: _openCreateEditor,
              onImport: _importItems,
              onExportAll: _exportAll,
              onRefresh: _refreshCurrentKind,
              onToggleTemplateFavorite: (template) =>
                  _toggleTemplateFavorite(template),
              onToggleConventionFavorite: (convention) =>
                  _toggleConventionFavorite(convention),
              onTemplateAction: _handleTemplateAction,
              onConventionAction: _handleConventionAction,
            ),
    );
  }

  void _setSearchQuery(String value) {
    if (_kind == _WorkflowKind.metadata) {
      ref
          .read(templateLibraryControllerProvider.notifier)
          .setSearchQuery(value);
      return;
    }

    ref.read(renameLibraryControllerProvider.notifier).setSearchQuery(value);
  }

  Future<void> _refreshCurrentKind() async {
    if (_kind == _WorkflowKind.metadata) {
      await ref.read(templateLibraryControllerProvider.notifier).refresh();
      return;
    }
    await ref.read(renameLibraryControllerProvider.notifier).refresh();
  }

  Future<void> _openCreateEditor() async {
    if (_kind == _WorkflowKind.metadata) {
      await _openTemplateEditor();
      return;
    }

    await _openRenameEditor();
  }

  Future<void> _toggleTemplateFavorite(MetadataTemplate template) async {
    await ref
        .read(templateLibraryControllerProvider.notifier)
        .saveTemplate(
          template.copyWith(isFavorite: !template.isFavorite),
          originalId: template.id,
        );
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
  }

  Future<void> _toggleConventionFavorite(RenameConvention convention) async {
    await ref
        .read(renameLibraryControllerProvider.notifier)
        .saveConvention(
          convention.copyWith(isFavorite: !convention.isFavorite),
          originalId: convention.id,
        );
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
  }

  Future<void> _handleTemplateAction(
    MetadataTemplate template,
    _LibraryAction action,
  ) async {
    switch (action) {
      case _LibraryAction.edit:
        await _openTemplateEditor(existing: template);
      case _LibraryAction.duplicate:
        await _duplicateTemplate(template);
      case _LibraryAction.export:
        await _exportSingleTemplate(template);
      case _LibraryAction.setDefault:
        await _setDefaultTemplate(template);
      case _LibraryAction.delete:
        await _deleteTemplate(template);
    }
  }

  Future<void> _handleConventionAction(
    RenameConvention convention,
    _LibraryAction action,
  ) async {
    switch (action) {
      case _LibraryAction.edit:
        await _openRenameEditor(existing: convention);
      case _LibraryAction.duplicate:
        await _duplicateConvention(convention);
      case _LibraryAction.export:
        await _exportSingleConvention(convention);
      case _LibraryAction.setDefault:
        await _setDefaultConvention(convention);
      case _LibraryAction.delete:
        await _deleteConvention(convention);
    }
  }

  Future<void> _setDefaultTemplate(MetadataTemplate template) async {
    await ref
        .read(appSettingsControllerProvider.notifier)
        .setDefaultTemplateId(template.id);
    _showSnack('"${template.name}" is now the default metadata template.');
  }

  Future<void> _setDefaultConvention(RenameConvention convention) async {
    await ref
        .read(appSettingsControllerProvider.notifier)
        .setDefaultConventionId(convention.id);
    _showSnack('"${convention.name}" is now the default naming convention.');
  }

  Future<void> _duplicateTemplate(MetadataTemplate template) async {
    final copyName = _resolveImportedName(
      'Copy of ${template.name}',
      ref
          .read(templateLibraryControllerProvider)
          .templates
          .map((template) => template.name)
          .toSet(),
    );
    final duplicate = template.copyWith(
      id: copyName,
      name: copyName,
      isFavorite: false,
    );
    await ref
        .read(templateLibraryControllerProvider.notifier)
        .saveTemplate(duplicate);
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
    await _openTemplateEditor(existing: duplicate);
  }

  Future<void> _duplicateConvention(RenameConvention convention) async {
    final copyName = _resolveImportedName(
      'Copy of ${convention.name}',
      ref
          .read(renameLibraryControllerProvider)
          .conventions
          .map((convention) => convention.name)
          .toSet(),
    );
    final duplicate = convention.copyWith(
      id: copyName,
      name: copyName,
      isFavorite: false,
    );
    await ref
        .read(renameLibraryControllerProvider.notifier)
        .saveConvention(duplicate);
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
    await _openRenameEditor(existing: duplicate);
  }

  Future<void> _deleteTemplate(MetadataTemplate template) async {
    // Clear default if this template is the default
    if (ref.read(appSettingsControllerProvider).defaultTemplateId == template.id) {
      await ref.read(appSettingsControllerProvider.notifier).setDefaultTemplateId(null);
    }

    final confirmed = await _confirmDelete(
      'Delete template "${template.name}"?',
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(templateLibraryControllerProvider.notifier)
        .deleteTemplate(template);
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
  }

  Future<void> _deleteConvention(RenameConvention convention) async {
    // Clear default if this convention is the default
    if (ref.read(appSettingsControllerProvider).defaultConventionId == convention.id) {
      await ref.read(appSettingsControllerProvider.notifier).setDefaultConventionId(null);
    }

    final confirmed = await _confirmDelete(
      'Delete rename rule "${convention.name}"?',
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(renameLibraryControllerProvider.notifier)
        .deleteConvention(convention);
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
  }

  Future<bool?> _confirmDelete(String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm delete'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSingleTemplate(MetadataTemplate template) async {
    final service = ref.read(importExportServiceProvider);
    final path = await service.chooseSavePath(
      dialogTitle: 'Export metadata template',
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
    _showSnack('Template exported: ${p.basename(path)}');
  }

  Future<void> _exportSingleConvention(RenameConvention convention) async {
    final service = ref.read(importExportServiceProvider);
    final path = await service.chooseSavePath(
      dialogTitle: 'Export rename rule',
      defaultFileName: '${convention.name}.json',
      allowedExtensions: const ['json'],
    );
    if (path == null) {
      return;
    }

    await service.exportSingleJson(
      payload: service.renameExportJson(convention),
      outputPath: path,
    );
    _showSnack('Rename rule exported: ${p.basename(path)}');
  }

  Future<void> _exportAll() async {
    final service = ref.read(importExportServiceProvider);
    final path = await service.chooseSavePath(
      dialogTitle: 'Export all $_kindLabelPluralLower',
      defaultFileName: _kind == _WorkflowKind.metadata
          ? 'all_metadata_templates.zip'
          : 'all_rename_rules.zip',
      allowedExtensions: const ['zip'],
    );
    if (path == null) {
      return;
    }

    if (_kind == _WorkflowKind.metadata) {
      final root = await ref
          .read(templateStorageServiceProvider)
          .ensureRootDirectory();
      await service.exportAllAsZip(rootDirectory: root, outputPath: path);
    } else {
      final root = await ref
          .read(renameConventionStorageServiceProvider)
          .ensureRootDirectory();
      await service.exportAllAsZip(rootDirectory: root, outputPath: path);
    }

    _showSnack('Exported $_kindLabelPluralLower: ${p.basename(path)}');
  }

  Future<void> _importItems() async {
    final service = ref.read(importExportServiceProvider);
    final paths = await service.chooseImportFiles();
    if (paths.isEmpty) {
      return;
    }

    final payloads = await service.loadImportPayloads(paths);
    final targetKind = _kind == _WorkflowKind.metadata
        ? ImportItemKind.metadataTemplate
        : ImportItemKind.renameConvention;
    final matching = payloads
        .where((payload) => payload.kind == targetKind)
        .toList(growable: false);
    final invalidCount = payloads.length - matching.length;
    if (_kind == _WorkflowKind.metadata) {
      await _importTemplates(service, matching);
    } else {
      await _importConventions(service, matching);
    }

    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
    _showSnack(
      '${matching.length} $_kindLabelPluralLower imported'
      '${invalidCount > 0 ? ' ($invalidCount skipped)' : ''}',
    );
  }

  Future<void> _importTemplates(
    ImportExportService service,
    List<ImportPayload> payloads,
  ) async {
    final controller = ref.read(templateLibraryControllerProvider.notifier);
    final current = [...ref.read(templateLibraryControllerProvider).templates];

    for (final payload in payloads) {
      var incoming = service
          .toTemplate(payload.rawJson)
          .copyWith(isFavorite: false);
      final existing = current.cast<MetadataTemplate?>().firstWhere(
        (template) =>
            template?.name.toLowerCase() == incoming.name.toLowerCase(),
        orElse: () => null,
      );
      if (existing != null) {
        final action = await _askImportConflict(incoming.name, 'template');
        if (action == _ImportConflictAction.cancel) {
          continue;
        }
        if (action == _ImportConflictAction.keepBoth) {
          incoming = incoming.copyWith(
            name: _resolveImportedName(
              incoming.name,
              current.map((template) => template.name).toSet(),
            ),
          );
          await controller.saveTemplate(incoming);
        } else {
          await controller.saveTemplate(incoming, originalId: existing.id);
        }
      } else {
        await controller.saveTemplate(incoming);
      }
      current.add(incoming);
    }
  }

  Future<void> _importConventions(
    ImportExportService service,
    List<ImportPayload> payloads,
  ) async {
    final controller = ref.read(renameLibraryControllerProvider.notifier);
    final current = [...ref.read(renameLibraryControllerProvider).conventions];

    for (final payload in payloads) {
      var incoming = service
          .toConvention(payload.rawJson)
          .copyWith(isFavorite: false);
      final existing = current.cast<RenameConvention?>().firstWhere(
        (convention) =>
            convention?.name.toLowerCase() == incoming.name.toLowerCase(),
        orElse: () => null,
      );
      if (existing != null) {
        final action = await _askImportConflict(incoming.name, 'rename rule');
        if (action == _ImportConflictAction.cancel) {
          continue;
        }
        if (action == _ImportConflictAction.keepBoth) {
          incoming = incoming.copyWith(
            name: _resolveImportedName(
              incoming.name,
              current.map((convention) => convention.name).toSet(),
            ),
          );
          await controller.saveConvention(incoming);
        } else {
          await controller.saveConvention(incoming, originalId: existing.id);
        }
      } else {
        await controller.saveConvention(incoming);
      }
      current.add(incoming);
    }
  }

  Future<_ImportConflictAction?> _askImportConflict(
    String name,
    String itemLabel,
  ) {
    return showDialog<_ImportConflictAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Duplicate $itemLabel'),
        content: Text('"$name" already exists. What should happen?'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _ImportConflictAction.cancel),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _ImportConflictAction.keepBoth),
            child: const Text('Keep Both'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _ImportConflictAction.replace),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTemplateEditor({MetadataTemplate? existing}) async {
    final result = await showDialog<MetadataTemplate>(
      context: context,
      builder: (context) => _MetadataTemplateEditorDialog(existing: existing),
    );
    if (result == null) {
      return;
    }

    await ref
        .read(templateLibraryControllerProvider.notifier)
        .saveTemplate(result, originalId: existing?.id);
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
  }

  Future<void> _openRenameEditor({RenameConvention? existing}) async {
    final result = await showDialog<RenameConvention>(
      context: context,
      builder: (context) => _RenameRuleEditorDialog(existing: existing),
    );
    if (result == null) {
      return;
    }

    await ref
        .read(renameLibraryControllerProvider.notifier)
        .saveConvention(result, originalId: existing?.id);
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();
  }

  String _resolveImportedName(String baseName, Set<String> existingNames) {
    var index = 2;
    var candidate = '$baseName $index';
    while (existingNames
        .map((name) => name.toLowerCase())
        .contains(candidate.toLowerCase())) {
      index++;
      candidate = '$baseName $index';
    }
    return candidate;
  }

  String get _kindLabelPluralLower =>
      _kind == _WorkflowKind.metadata ? 'metadata templates' : 'rename rules';

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WorkflowLibraryPane extends StatelessWidget {
  const _WorkflowLibraryPane({
    required this.kind,
    required this.templateState,
    required this.renameState,
    required this.showFavoritesOnly,
    required this.defaultTemplateId,
    required this.defaultConventionId,
    required this.onKindChanged,
    required this.onFavoritesOnlyChanged,
    required this.onSearchChanged,
    required this.onCreate,
    required this.onImport,
    required this.onExportAll,
    required this.onRefresh,
    required this.onToggleTemplateFavorite,
    required this.onToggleConventionFavorite,
    required this.onTemplateAction,
    required this.onConventionAction,
  });

  final _WorkflowKind kind;
  final TemplateLibraryState templateState;
  final RenameLibraryState renameState;
  final bool showFavoritesOnly;
  final String? defaultTemplateId;
  final String? defaultConventionId;
  final ValueChanged<_WorkflowKind> onKindChanged;
  final ValueChanged<bool> onFavoritesOnlyChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;
  final VoidCallback onImport;
  final VoidCallback onExportAll;
  final VoidCallback onRefresh;
  final ValueChanged<MetadataTemplate> onToggleTemplateFavorite;
  final ValueChanged<RenameConvention> onToggleConventionFavorite;
  final void Function(MetadataTemplate, _LibraryAction) onTemplateAction;
  final void Function(RenameConvention, _LibraryAction) onConventionAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = templateState.filteredTemplates
        .where((template) => !showFavoritesOnly || template.isFavorite)
        .toList(growable: false);
    final conventions = renameState.filteredConventions
        .where((convention) => !showFavoritesOnly || convention.isFavorite)
        .toList(growable: false);
    final itemCount = kind == _WorkflowKind.metadata
        ? templates.length
        : conventions.length;
    final title = kind == _WorkflowKind.metadata
        ? 'Metadata Templates'
        : 'Rename Rules';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<_WorkflowKind>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: _WorkflowKind.metadata,
                            icon: Icon(Icons.layers_outlined),
                            label: Text('Metadata'),
                          ),
                          ButtonSegment(
                            value: _WorkflowKind.rename,
                            icon: Icon(Icons.drive_file_rename_outline),
                            label: Text('Rename'),
                          ),
                        ],
                        selected: {kind},
                        onSelectionChanged: (selection) =>
                            onKindChanged(selection.first),
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                        ),
                        label: Text('$itemCount item(s)'),
                        visualDensity: VisualDensity.compact,
                      ),
                      FilterChip(
                        avatar: const Icon(Icons.star, size: 18),
                        label: const Text('Favorites'),
                        selected: showFavoritesOnly,
                        onSelected: onFavoritesOnlyChanged,
                        visualDensity: VisualDensity.compact,
                      ),
                      OutlinedButton.icon(
                        onPressed: onImport,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Import'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onExportAll,
                        icon: const Icon(Icons.ios_share_outlined),
                        label: const Text('Export All'),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SearchBar(
                          hintText: 'Search $title',
                          leading: const Icon(Icons.search),
                          onChanged: onSearchChanged,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: onCreate,
                        icon: const Icon(Icons.add),
                        label: Text(
                          kind == _WorkflowKind.metadata
                              ? 'New Template'
                              : 'New Rule',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: itemCount == 0
                ? _WorkflowEmptyState(kind: kind, onCreate: onCreate)
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 440,
                          mainAxisExtent: 164,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (kind == _WorkflowKind.metadata) {
                        final template = templates[index];
                        return _MetadataTemplateCard(
                          template: template,
                          isDefault: template.id == defaultTemplateId,
                          onToggleFavorite: () =>
                              onToggleTemplateFavorite(template),
                          onAction: (action) =>
                              onTemplateAction(template, action),
                        );
                      }

                      final convention = conventions[index];
                      return _RenameRuleCard(
                        convention: convention,
                        isDefault: convention.id == defaultConventionId,
                        onToggleFavorite: () =>
                            onToggleConventionFavorite(convention),
                        onAction: (action) =>
                            onConventionAction(convention, action),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowEmptyState extends StatelessWidget {
  const _WorkflowEmptyState({required this.kind, required this.onCreate});

  final _WorkflowKind kind;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final isMetadata = kind == _WorkflowKind.metadata;
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMetadata
                  ? Icons.layers_outlined
                  : Icons.drive_file_rename_outline,
              size: 52,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              isMetadata ? 'No metadata templates yet' : 'No rename rules yet',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isMetadata
                  ? 'Create reusable metadata presets for titles, descriptions, keywords, copyright, and creators.'
                  : 'Create naming patterns that turn batches into predictable, organized filenames.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(isMetadata ? 'Create Template' : 'Create Rule'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataTemplateCard extends StatelessWidget {
  const _MetadataTemplateCard({
    required this.template,
    required this.isDefault,
    required this.onToggleFavorite,
    required this.onAction,
  });

  final MetadataTemplate template;
  final bool isDefault;
  final VoidCallback onToggleFavorite;
  final ValueChanged<_LibraryAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = template.fields.keys.take(4).toList(growable: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onAction(_LibraryAction.edit),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: template.isFavorite
                        ? 'Remove favorite'
                        : 'Mark favorite',
                    onPressed: onToggleFavorite,
                    icon: Icon(
                      template.isFavorite ? Icons.star : Icons.star_border,
                      color: template.isFavorite ? Colors.amber : null,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _ItemActionMenu(onSelected: onAction),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${template.fields.length} metadata field(s)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (isDefault)
                    const Chip(
                      avatar: Icon(Icons.check_circle_outline, size: 16),
                      label: Text('Default'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (fields.isEmpty)
                    const Chip(
                      label: Text('No fields yet'),
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    for (final field in fields)
                      Chip(
                        label: Text(field),
                        visualDensity: VisualDensity.compact,
                      ),
                  if (template.fields.length > fields.length)
                    Chip(
                      label: Text('+${template.fields.length - fields.length}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenameRuleCard extends StatelessWidget {
  const _RenameRuleCard({
    required this.convention,
    required this.isDefault,
    required this.onToggleFavorite,
    required this.onAction,
  });

  final RenameConvention convention;
  final bool isDefault;
  final VoidCallback onToggleFavorite;
  final ValueChanged<_LibraryAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sample = applyRenamePattern(
      pattern: convention.pattern,
      date: DateTime(2026, 5, 1, 10, 30),
      sequence: 1,
      title: 'Sample',
      metadata: const {
        'author': 'alex_gledhill',
        'camera model': 'Sony_A7R_V',
        'iso': '400',
        'lensmodel': '35mm_f1.4',
        'datetimeoriginal': '2026:05:01_10:30:22',
      },
      extension: '.jpg',
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onAction(_LibraryAction.edit),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: convention.isFavorite
                        ? 'Remove favorite'
                        : 'Mark favorite',
                    onPressed: onToggleFavorite,
                    icon: Icon(
                      convention.isFavorite ? Icons.star : Icons.star_border,
                      color: convention.isFavorite ? Colors.amber : null,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      convention.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _ItemActionMenu(onSelected: onAction),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                convention.pattern,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isDefault) ...[
                const SizedBox(height: 8),
                const Chip(
                  avatar: Icon(Icons.check_circle_outline, size: 16),
                  label: Text('Default'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
              const Spacer(),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.42,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sample,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemActionMenu extends StatelessWidget {
  const _ItemActionMenu({required this.onSelected});

  final ValueChanged<_LibraryAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LibraryAction>(
      tooltip: 'More actions',
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _LibraryAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _LibraryAction.duplicate,
          child: ListTile(
            leading: Icon(Icons.copy_outlined),
            title: Text('Duplicate'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _LibraryAction.export,
          child: ListTile(
            leading: Icon(Icons.ios_share_outlined),
            title: Text('Export'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _LibraryAction.setDefault,
          child: ListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('Set as Default'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _LibraryAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _MetadataTemplateEditorDialog extends StatefulWidget {
  const _MetadataTemplateEditorDialog({this.existing});

  final MetadataTemplate? existing;

  @override
  State<_MetadataTemplateEditorDialog> createState() =>
      _MetadataTemplateEditorDialogState();
}

class _MetadataTemplateEditorDialogState
    extends State<_MetadataTemplateEditorDialog> {
  late final TextEditingController _nameController;
  late final Set<String> _selectedFields;
  late final Map<String, String> _fieldValues;
  String? _nameError;

  static const _metadataFields = <String, List<String>>{
    'Common': [
      'XMP.Title',
      'XMP.Description',
      'XMP.Keywords',
      'XMP.Headline',
      'XMP.Creator',
      'XMP.Copyright',
    ],
    'IPTC': [
      'IPTC.Headline',
      'IPTC.Keywords',
      'IPTC.Caption',
      'IPTC.CopyrightNotice',
      'IPTC.Creator',
      'IPTC.CreatorJobTitle',
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
    'Advanced': [
      'XMP.CreatorContactInfo',
      'XMP.Rights',
      'XMP.Subject',
      'XMP.Rating',
    ],
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedFields = {...widget.existing?.fields.keys ?? const <String>{}};
    _fieldValues = {...widget.existing?.fields ?? const <String, String>{}};
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Create Metadata Template'
            : 'Edit Metadata Template',
      ),
      content: SizedBox(
        width: 920,
        height: 620,
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Template name',
              ).copyWith(errorText: _nameError),
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView(
                        children: [
                          for (final group in _metadataFields.entries)
                            Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ExpansionTile(
                                initiallyExpanded: group.key == 'Common',
                                title: Text(group.key),
                                subtitle: Text(
                                  '${group.value.where(_selectedFields.contains).length} selected',
                                ),
                                children: [
                                  for (final field in group.value)
                                    _MetadataFieldEditor(
                                      field: field,
                                      selected: _selectedFields.contains(field),
                                      value: _fieldValues[field] ?? '',
                                      onSelectedChanged: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedFields.add(field);
                                          } else {
                                            _selectedFields.remove(field);
                                          }
                                        });
                                      },
                                      onValueChanged: (value) =>
                                          _fieldValues[field] = value,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: _EditorPreviewCard(
                      title: 'Template preview',
                      icon: Icons.layers_outlined,
                      children: [
                        Text(
                          '${_selectedFields.length} field(s) will be written.',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Blank values preserve existing metadata during apply.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Divider(height: 22),
                        if (_selectedFields.isEmpty)
                          const Text('Choose fields to build this template.')
                        else
                          for (final field in _selectedFields.take(10))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(field),
                              subtitle: Text(
                                (_fieldValues[field] ?? '').isEmpty
                                    ? 'Preserve existing'
                                    : _fieldValues[field]!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Template'),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter a template name before saving.');
      return;
    }

    Navigator.pop(
      context,
      MetadataTemplate(
        id: widget.existing?.id ?? name,
        name: name,
        isFavorite: widget.existing?.isFavorite ?? false,
        folderPath: widget.existing?.folderPath ?? '',
        fields: {
          for (final field in _selectedFields) field: _fieldValues[field] ?? '',
        },
      ),
    );
  }
}

class _MetadataFieldEditor extends StatelessWidget {
  const _MetadataFieldEditor({
    required this.field,
    required this.selected,
    required this.value,
    required this.onSelectedChanged,
    required this.onValueChanged,
  });

  final String field;
  final bool selected;
  final String value;
  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<String> onValueChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(field),
            value: selected,
            onChanged: onSelectedChanged,
          ),
          if (selected)
            TextFormField(
              initialValue: value,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Value',
                helperText: 'Leave blank to preserve existing metadata',
              ),
              onChanged: onValueChanged,
            ),
        ],
      ),
    );
  }
}

class _RenameRuleEditorDialog extends StatefulWidget {
  const _RenameRuleEditorDialog({this.existing});

  final RenameConvention? existing;

  @override
  State<_RenameRuleEditorDialog> createState() =>
      _RenameRuleEditorDialogState();
}

class _RenameRuleEditorDialogState extends State<_RenameRuleEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _patternController;
  String? _nameError;
  String? _patternError;

  static const _dateTokens = [
    '{year}',
    '{month}',
    '{day}',
    '{hour}',
    '{minute}',
    '{second}',
  ];
  static const _sequenceTokens = ['{sequence}', '{sequence:2}', '{sequence:3}'];
  static const _metadataTokens = [
    '{metadata:author}',
    '{metadata:camera model}',
    '{metadata:iso}',
    '{metadata:lensmodel}',
    '{metadata:datetimeoriginal}',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _patternController = TextEditingController(
      text:
          widget.existing?.pattern ??
          '{year}-{month}-{day}_{sequence:3}_{metadata:author}',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Create Rename Rule' : 'Edit Rename Rule',
      ),
      content: SizedBox(
        width: 920,
        height: 560,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ListView(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Rule name',
                      errorText: _nameError,
                    ),
                    onChanged: (_) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _patternController,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Pattern',
                      helperText:
                          'Example: {year}-{month}-{day}_{sequence:3}_{metadata:author}',
                    ).copyWith(errorText: _patternError),
                  ),
                  const SizedBox(height: 12),
                  _TokenGroup(
                    title: 'Date tokens',
                    tokens: _dateTokens,
                    onInsert: _insertToken,
                  ),
                  _TokenGroup(
                    title: 'Sequence tokens',
                    tokens: _sequenceTokens,
                    onInsert: _insertToken,
                  ),
                  _TokenGroup(
                    title: 'Metadata tokens',
                    tokens: _metadataTokens,
                    onInsert: _insertToken,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: _EditorPreviewCard(
                title: 'Live preview',
                icon: Icons.drive_file_rename_outline,
                children: [
                  for (final entry in _sampleRows().entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PreviewPair(
                        original: entry.key,
                        renamed: entry.value,
                      ),
                    ),
                  if (_warnings().isNotEmpty) ...[
                    const Divider(height: 22),
                    for (final warning in _warnings())
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.warning_amber_outlined),
                        title: Text(warning),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Rule'),
        ),
      ],
    );
  }

  Map<String, String> _sampleRows() {
    final now = DateTime(2026, 5, 1, 10, 30, 22);
    return {
      for (var index = 0; index < 4; index++)
        'IMG_${1000 + index}.jpg': applyRenamePattern(
          pattern: _patternController.text,
          date: now,
          sequence: index + 1,
          title: 'Sample ${index + 1}',
          metadata: const {
            'author': 'alex_gledhill',
            'camera model': 'Sony_A7R_V',
            'iso': '400',
            'lensmodel': '35mm_f1.4',
            'datetimeoriginal': '2026:05:01_10:30:22',
          },
          extension: '.jpg',
        ),
    };
  }

  List<String> _warnings() {
    final pattern = _patternController.text.trim();
    final warnings = <String>[];
    if (pattern.isEmpty) {
      warnings.add('Pattern cannot be empty.');
    }
    if (!pattern.contains('{sequence')) {
      warnings.add('Add a sequence token to avoid duplicate filenames.');
    }
    if (RegExp(
      r'[\\/:*?"<>|]',
    ).hasMatch(pattern.replaceAll(RegExp(r'\{[^}]+\}'), ''))) {
      warnings.add('Static text contains unsafe filename characters.');
    }
    final renamed = _sampleRows().values.toList(growable: false);
    if (renamed.toSet().length != renamed.length) {
      warnings.add('Preview contains duplicate output names.');
    }
    return warnings;
  }

  void _insertToken(String token) {
    final old = _patternController.text;
    final selection = _patternController.selection;
    final start = selection.start < 0 ? old.length : selection.start;
    final end = selection.end < 0 ? old.length : selection.end;
    final updated = old.replaceRange(start, end, token);
    _patternController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    setState(() {});
  }

  void _save() {
    final name = _nameController.text.trim();
    final pattern = _patternController.text.trim();
    if (name.isEmpty || pattern.isEmpty) {
      setState(() {
        _nameError = name.isEmpty
            ? 'Enter a rename rule name before saving.'
            : null;
        _patternError = pattern.isEmpty
            ? 'Enter a naming pattern before saving.'
            : null;
      });
      return;
    }

    Navigator.pop(
      context,
      RenameConvention(
        id: widget.existing?.id ?? name,
        name: name,
        pattern: pattern,
        isFavorite: widget.existing?.isFavorite ?? false,
        folderPath: widget.existing?.folderPath ?? '',
      ),
    );
  }
}

class _TokenGroup extends StatelessWidget {
  const _TokenGroup({
    required this.title,
    required this.tokens,
    required this.onInsert,
  });

  final String title;
  final List<String> tokens;
  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final token in tokens)
                  ActionChip(
                    label: Text(token),
                    onPressed: () => onInsert(token),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorPreviewCard extends StatelessWidget {
  const _EditorPreviewCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.34,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ListView(
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PreviewPair extends StatelessWidget {
  const _PreviewPair({required this.original, required this.renamed});

  final String original;
  final String renamed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              original,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    renamed,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
