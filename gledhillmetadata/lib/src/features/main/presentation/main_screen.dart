import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../settings/application/app_settings_controller.dart';
import '../../photo_browser/application/photo_browser_controller.dart';
import '../../../models/metadata_template.dart';
import '../../../models/photo_item.dart';
import '../../../models/rename_convention.dart';
import '../../../state/providers.dart';
import '../../../utils/keyboard_shortcuts.dart';
import '../../../utils/rename_pattern.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  String? _selectedTemplateId;
  String? _selectedConventionId;
  bool _isApplying = false;
  double _applyProgress = 0;
  String? _applyCurrentFile;
  bool _isRenamePreviewExpanded = false;

  // Cached shortcut callbacks, updated every build so key handler always has
  // the freshest state without capturing stale closure variables.
  final Map<PhotoShortcutCommand, VoidCallback> _shortcutCallbacks = {};

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!widget.isActive) return false;
    final settings = ref.read(appSettingsControllerProvider);
    for (final entry in _effectiveShortcuts(settings).entries) {
      if (entry.value.activator.accepts(event, HardwareKeyboard.instance)) {
        _shortcutCallbacks[entry.key]?.call();
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final browserState = ref.watch(photoBrowserControllerProvider);
    final browserController = ref.read(photoBrowserControllerProvider.notifier);
    final catalog = ref.watch(libraryCatalogControllerProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final settingsController = ref.read(appSettingsControllerProvider.notifier);

    final templates = catalog.templates;
    final conventions = catalog.conventions;
    final templateIds = templates.map((template) => template.id).toSet();
    final conventionIds = conventions
        .map((convention) => convention.id)
        .toSet();
    final templateOverride =
        _selectedTemplateId != null && templateIds.contains(_selectedTemplateId)
        ? _selectedTemplateId
        : null;
    final conventionOverride =
        _selectedConventionId != null &&
            conventionIds.contains(_selectedConventionId)
        ? _selectedConventionId
        : null;
    final defaultTemplateId =
        settings.defaultTemplateId != null &&
            templateIds.contains(settings.defaultTemplateId)
        ? settings.defaultTemplateId
        : null;
    final defaultConventionId =
        settings.defaultConventionId != null &&
            conventionIds.contains(settings.defaultConventionId)
        ? settings.defaultConventionId
        : null;
    final effectiveTemplateId = templateOverride ?? defaultTemplateId;
    final effectiveConventionId = conventionOverride ?? defaultConventionId;

    MetadataTemplate? selectedTemplate;
    for (final template in templates) {
      if (template.id == effectiveTemplateId) {
        selectedTemplate = template;
        break;
      }
    }

    RenameConvention? selectedConvention;
    for (final convention in conventions) {
      if (convention.id == effectiveConventionId) {
        selectedConvention = convention;
        break;
      }
    }

    final selectedPhotos = browserState.selectedPhotos;
    final canApply =
        selectedPhotos.isNotEmpty &&
        selectedTemplate != null &&
        selectedConvention != null &&
        !_isApplying;

    final focusedPhoto = _focusedPhoto(browserState);

    void applySelection() {
      final template = selectedTemplate;
      final convention = selectedConvention;
      if (template == null || convention == null || selectedPhotos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Select photos, a metadata template, and a naming convention first.',
            ),
          ),
        );
        return;
      }

      _confirmAndApply(
        selectedPhotos: selectedPhotos,
        selectedTemplate: template,
        selectedConvention: convention,
        mergeStrategy: settings.mergeStrategy,
      );
    }

    // Keep callbacks fresh so the HardwareKeyboard handler always dispatches
    // with the latest state.
    _shortcutCallbacks[PhotoShortcutCommand.selectAll] = _isApplying
        ? () {}
        : browserController.selectAllPhotos;
    _shortcutCallbacks[PhotoShortcutCommand.unselectAll] = _isApplying
        ? () {}
        : browserController.clearSelection;
    _shortcutCallbacks[PhotoShortcutCommand.deleteSelected] = _isApplying
        ? () {}
        : browserController.removeSelectedPhotos;
    _shortcutCallbacks[PhotoShortcutCommand.apply] = _isApplying
        ? () {}
        : applySelection;
    _shortcutCallbacks[PhotoShortcutCommand.pickPhotos] = _isApplying
        ? () {}
        : browserController.pickPhotos;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final outlineColor = theme.colorScheme.outlineVariant;
          final panelColor = theme.colorScheme.surface.withValues(alpha: 0.35);
          final panelDecoration = BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: outlineColor),
          );

          final isCompact =
              constraints.maxWidth < 820 || constraints.maxHeight < 680;
          final pagePadding = isCompact ? 8.0 : 12.0;
          final panelPadding = isCompact ? 10.0 : 16.0;
          final gap = isCompact ? 6.0 : 10.0;
          final isWide = constraints.maxWidth >= 1040;
          final showBottomPanel = constraints.maxHeight >= 760;
          final sidePanelWidth = constraints.maxWidth < 1280 ? 320.0 : 380.0;
          final hasPhotos = browserState.photos.isNotEmpty;

          final mainContent = Focus(
            autofocus: true,
            child: DropTarget(
              onDragEntered: (_) => browserController.setDragging(true),
              onDragExited: (_) => browserController.setDragging(false),
              onDragDone: (details) {
                browserController.setDragging(false);
                browserController.addDroppedFiles(
                  details.files.cast<dynamic>(),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: browserState.isDragging
                    ? const EdgeInsets.all(2)
                    : EdgeInsets.zero,
                decoration: browserState.isDragging
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasPhotos)
                      _PhotoWorkspaceToolbar(
                        totalCount: browserState.photos.length,
                        selectedCount: browserState.selectedPhotos.length,
                        viewMode: settings.photoViewMode,
                        gridSize: settings.photoGridSize,
                        isCompact: isCompact,
                        onPickPhotos: browserController.pickPhotos,
                        onSelectAll: browserController.selectAllPhotos,
                        onClearSelection: browserController.clearSelection,
                        onRemoveSelected: browserState.selectedPhotos.isEmpty
                            ? null
                            : browserController.removeSelectedPhotos,
                        onViewModeChanged: settingsController.setPhotoViewMode,
                        onGridSizeChanged: settingsController.setPhotoGridSize,
                      )
                    else
                      Expanded(
                        child: _EmptyImportPanel(
                          isDragging: browserState.isDragging,
                          decoration: panelDecoration,
                          padding: panelPadding,
                          onPickPhotos: browserController.pickPhotos,
                        ),
                      ),
                    if (browserState.errorMessage != null) ...[
                      SizedBox(height: gap),
                      _ErrorNotice(
                        message: browserState.errorMessage!,
                        showFullDetails: settings.showFullErrorDetails,
                        onDismiss: browserController.clearError,
                      ),
                    ],
                    if (hasPhotos) ...[
                      SizedBox(height: gap),
                      _WorkflowBar(
                        templates: templates,
                        conventions: conventions,
                        selectedTemplateId: effectiveTemplateId,
                        selectedConventionId: effectiveConventionId,
                        onTemplateSelected: (id) {
                          setState(() => _selectedTemplateId = id);
                        },
                        onConventionSelected: (id) {
                          setState(() => _selectedConventionId = id);
                        },
                      ),
                      SizedBox(height: gap),
                      Expanded(
                        child: _PhotoBrowserArea(
                          photos: browserState.photos,
                          viewMode: settings.photoViewMode,
                          gridSize: settings.photoGridSize,
                          decoration: panelDecoration,
                          onFocus: browserController.focusPhoto,
                          onToggleSelection: browserController.toggleSelection,
                        ),
                      ),
                      SizedBox(height: gap),
                      _RenamePreviewPanel(
                        photos: selectedPhotos,
                        selectedTemplate: selectedTemplate,
                        selectedConvention: selectedConvention,
                        isExpanded: _isRenamePreviewExpanded,
                        isCompact: isCompact,
                        decoration: panelDecoration,
                        onToggleExpanded: () {
                          setState(() {
                            _isRenamePreviewExpanded =
                                !_isRenamePreviewExpanded;
                          });
                        },
                      ),
                      SizedBox(height: gap),
                      _ApplyActionBar(
                        canApply: canApply,
                        isApplying: _isApplying,
                        progress: _applyProgress,
                        currentFile: _applyCurrentFile,
                        selectedCount: selectedPhotos.length,
                        onApply: applySelection,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );

          return Padding(
            padding: EdgeInsets.all(pagePadding),
            child: isWide
                ? Row(
                    children: [
                      Expanded(child: mainContent),
                      SizedBox(width: pagePadding),
                      SizedBox(
                        width: sidePanelWidth,
                        child: _MetadataSidePanel(photo: focusedPhoto),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: mainContent),
                      if (showBottomPanel) ...[
                        SizedBox(height: gap),
                        SizedBox(
                          height: 220,
                          child: _MetadataSidePanel(photo: focusedPhoto),
                        ),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }

  Map<PhotoShortcutCommand, KeyboardShortcutBinding> _effectiveShortcuts(
    AppSettingsState settings,
  ) {
    return {
      for (final command in PhotoShortcutCommand.values)
        command:
            settings.keyboardShortcuts[command] ??
            KeyboardShortcutBinding.defaultFor(command),
    };
  }

  Future<void> _apply({
    required List<PhotoItem> selectedPhotos,
    required MetadataTemplate selectedTemplate,
    required RenameConvention selectedConvention,
    required MetadataMergeStrategy mergeStrategy,
  }) async {
    final service = ref.read(batchApplyServiceProvider);
    setState(() {
      _isApplying = true;
      _applyProgress = 0;
      _applyCurrentFile = null;
    });

    final result = await service.apply(
      photos: selectedPhotos,
      template: selectedTemplate,
      convention: selectedConvention,
      mergeStrategy: mergeStrategy,
      onProgress: (progress) async {
        if (!mounted) {
          return;
        }
        setState(() {
          _applyProgress = progress.current / progress.total;
          _applyCurrentFile = p.basename(progress.filePath);
        });
      },
    );

    ref
        .read(photoBrowserControllerProvider.notifier)
        .applyPathUpdates(result.pathMappings);
    await ref
        .read(photoBrowserControllerProvider.notifier)
        .refreshAllMetadata();
    await ref.read(libraryCatalogControllerProvider.notifier).refresh();

    if (!mounted) {
      return;
    }

    setState(() {
      _isApplying = false;
      _applyProgress = 0;
      _applyCurrentFile = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Processed ${result.processed} photo(s): ${result.metadataWrittenCount} metadata write(s), '
          '${result.renamedCount} rename(s).',
        ),
      ),
    );

    if (result.errors.isNotEmpty && mounted) {
      await ref
          .read(appSettingsControllerProvider.notifier)
          .recordErrors(result.errors);

      if (!mounted) {
        return;
      }

      final showFullErrors = ref
          .read(appSettingsControllerProvider)
          .showFullErrorDetails;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            showFullErrors
                ? 'Completed with ${result.errors.length} warning(s).'
                : 'Completed with warning(s). Details are saved in Settings.',
          ),
          action: showFullErrors
              ? SnackBarAction(
                  label: 'View',
                  onPressed: () => _showApplyWarningsDialog(result.errors),
                )
              : null,
          duration: Duration(seconds: showFullErrors ? 6 : 4),
        ),
      );

      if (showFullErrors) {
        _showApplyWarningsDialog(result.errors);
      }
    }
  }

  Future<void> _confirmAndApply({
    required List<PhotoItem> selectedPhotos,
    required MetadataTemplate selectedTemplate,
    required RenameConvention selectedConvention,
    required MetadataMergeStrategy mergeStrategy,
  }) async {
    final settings = ref.read(appSettingsControllerProvider);
    if (settings.showApplyConfirmation) {
      final confirmed = await _showApplyConfirmationDialog(
        selectedPhotos: selectedPhotos,
        selectedTemplate: selectedTemplate,
        selectedConvention: selectedConvention,
      );
      if (confirmed != true) {
        return;
      }
    }

    await _apply(
      selectedPhotos: selectedPhotos,
      selectedTemplate: selectedTemplate,
      selectedConvention: selectedConvention,
      mergeStrategy: mergeStrategy,
    );
  }

  Future<bool?> _showApplyConfirmationDialog({
    required List<PhotoItem> selectedPhotos,
    required MetadataTemplate selectedTemplate,
    required RenameConvention selectedConvention,
  }) {
    var dontShowAgain = false;
    final previewRows = [
      for (var i = 0; i < selectedPhotos.length; i++)
        MapEntry(
          selectedPhotos[i].fileName,
          _previewNameFor(
            photo: selectedPhotos[i],
            index: i,
            template: selectedTemplate,
            convention: selectedConvention,
          ),
        ),
    ];

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Apply'),
              content: SizedBox(
                width: 760,
                height: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will change ${selectedPhotos.length} photo(s) using "${selectedConvention.name}" and "${selectedTemplate.name}".',
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: previewRows.length > 8,
                        child: ListView.separated(
                          itemCount: previewRows.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 12),
                          itemBuilder: (context, index) {
                            final row = previewRows[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                row.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                row.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: dontShowAgain,
                      onChanged: (value) =>
                          setDialogState(() => dontShowAgain = value ?? false),
                      title: const Text("Don't show again"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (dontShowAgain) {
                      await ref
                          .read(appSettingsControllerProvider.notifier)
                          .setShowApplyConfirmation(false);
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Accept'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showApplyWarningsDialog(List<String> errors) async {
    if (!mounted || errors.isEmpty) {
      return;
    }

    final allText = errors.join('\n');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Apply warnings'),
          content: SizedBox(
            width: 720,
            height: 320,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(child: SelectableText(allText)),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: allText));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Warnings copied to clipboard.'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy all'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _previewNameFor({
    required PhotoItem photo,
    required int index,
    required MetadataTemplate template,
    required RenameConvention convention,
  }) {
    final effectiveMetadata = _metadataAfterTemplate(
      original: photo.fullMetadata,
      template: template,
    );
    final title =
        _firstMetadataValue(effectiveMetadata, const ['XMP.Title', 'Title']) ??
        photo.metadataSummary['Title'] ??
        p.basenameWithoutExtension(photo.fileName);

    return applyRenamePattern(
      pattern: convention.pattern,
      date: DateTime.now(),
      sequence: index + 1,
      title: title,
      metadata: effectiveMetadata,
      extension: p.extension(photo.fileName),
    );
  }

  Map<String, String> _metadataAfterTemplate({
    required Map<String, String> original,
    required MetadataTemplate template,
  }) {
    final output = <String, String>{...original};
    for (final entry in template.fields.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        continue;
      }
      final key = entry.key.trim();
      final shortKey = key.contains('.') ? key.split('.').last : key;
      output[key] = value;
      output[shortKey] = value;
      output[key.replaceAll('.', ' ')] = value;
      if (shortKey.toLowerCase() == 'creator') {
        output['author'] = value;
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

  PhotoItem? _focusedPhoto(PhotoBrowserState browserState) {
    if (browserState.photos.isEmpty) {
      return null;
    }

    final focusedPath = browserState.focusedPhotoPath;
    if (focusedPath != null) {
      for (final photo in browserState.photos) {
        if (photo.path == focusedPath) {
          return photo;
        }
      }
    }

    final selected = browserState.selectedPhotos;
    if (selected.isNotEmpty) {
      return selected.first;
    }
    return browserState.photos.first;
  }
}

class _EmptyImportPanel extends StatelessWidget {
  const _EmptyImportPanel({
    required this.isDragging,
    required this.decoration,
    required this.padding,
    required this.onPickPhotos,
  });

  final bool isDragging;
  final BoxDecoration decoration;
  final double padding;
  final VoidCallback onPickPhotos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.all(padding),
      decoration: decoration.copyWith(
        color: isDragging
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.32)
            : decoration.color,
        border: Border.all(
          color: isDragging
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isDragging ? 2 : 1,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                isDragging ? 'Drop photos to import' : 'Start with photos',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Drag images into this window or open Finder to select files.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onPickPhotos,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Pick Photos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({
    required this.message,
    required this.showFullDetails,
    required this.onDismiss,
  });

  final String message;
  final bool showFullDetails;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (showFullDetails) {
      return MaterialBanner(
        content: Text(message),
        leading: const Icon(Icons.error_outline),
        actions: [
          TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Something needs attention. Full details are saved in Settings.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoWorkspaceToolbar extends StatelessWidget {
  const _PhotoWorkspaceToolbar({
    required this.totalCount,
    required this.selectedCount,
    required this.viewMode,
    required this.gridSize,
    required this.isCompact,
    required this.onPickPhotos,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onRemoveSelected,
    required this.onViewModeChanged,
    required this.onGridSizeChanged,
  });

  final int totalCount;
  final int selectedCount;
  final PhotoViewMode viewMode;
  final double gridSize;
  final bool isCompact;
  final VoidCallback onPickPhotos;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback? onRemoveSelected;
  final ValueChanged<PhotoViewMode> onViewModeChanged;
  final ValueChanged<double> onGridSizeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.36,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text('$selectedCount selected · $totalCount total'),
              visualDensity: VisualDensity.compact,
            ),
            FilledButton.icon(
              style: compactStyle,
              onPressed: onPickPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(isCompact ? 'Pick' : 'Pick Photos'),
            ),
            Tooltip(
              message: 'Select all photos',
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: onSelectAll,
                icon: const Icon(Icons.select_all),
              ),
            ),
            Tooltip(
              message: 'Clear selection',
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: onClearSelection,
                icon: const Icon(Icons.deselect),
              ),
            ),
            Tooltip(
              message: 'Remove selected photos',
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: onRemoveSelected,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ),
            SegmentedButton<PhotoViewMode>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12),
                ),
              ),
              segments: [
                ButtonSegment<PhotoViewMode>(
                  value: PhotoViewMode.list,
                  icon: const Icon(Icons.view_list_outlined),
                  label: const Text('List'),
                ),
                ButtonSegment<PhotoViewMode>(
                  value: PhotoViewMode.grid,
                  icon: const Icon(Icons.grid_view_outlined),
                  label: const Text('Grid'),
                ),
              ],
              selected: {viewMode},
              onSelectionChanged: (selection) =>
                  onViewModeChanged(selection.first),
            ),
            if (viewMode == PhotoViewMode.grid)
              SizedBox(
                width: isCompact ? 170 : 230,
                child: Row(
                  children: [
                    const Icon(Icons.photo_size_select_large_outlined),
                    Expanded(
                      child: Slider(
                        value: gridSize.clamp(140, 360).toDouble(),
                        min: 140,
                        max: 360,
                        divisions: 4,
                        label: _gridSizeLabel(gridSize),
                        onChanged: onGridSizeChanged,
                      ),
                    ),
                    Text(
                      _gridSizeLabel(gridSize),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _gridSizeLabel(double value) {
    final labels = ['Small', 'Small+', 'Medium', 'Large-', 'Large'];
    final index = (((value.clamp(140, 360) - 140) / 55).round())
        .clamp(0, 4)
        .toInt();
    return labels[index];
  }
}

class _WorkflowBar extends StatelessWidget {
  const _WorkflowBar({
    required this.templates,
    required this.conventions,
    required this.selectedTemplateId,
    required this.selectedConventionId,
    required this.onTemplateSelected,
    required this.onConventionSelected,
  });

  final List<MetadataTemplate> templates;
  final List<RenameConvention> conventions;
  final String? selectedTemplateId;
  final String? selectedConventionId;
  final ValueChanged<String?> onTemplateSelected;
  final ValueChanged<String?> onConventionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 720;

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TemplateSelector(
                    templates: templates,
                    selectedTemplateId: selectedTemplateId,
                    onSelected: onTemplateSelected,
                  ),
                  const SizedBox(height: 8),
                  _ConventionSelector(
                    conventions: conventions,
                    selectedConventionId: selectedConventionId,
                    onSelected: onConventionSelected,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _TemplateSelector(
                    templates: templates,
                    selectedTemplateId: selectedTemplateId,
                    onSelected: onTemplateSelected,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ConventionSelector(
                    conventions: conventions,
                    selectedConventionId: selectedConventionId,
                    onSelected: onConventionSelected,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RenamePreviewPanel extends StatelessWidget {
  const _RenamePreviewPanel({
    required this.photos,
    required this.selectedTemplate,
    required this.selectedConvention,
    required this.isExpanded,
    required this.isCompact,
    required this.decoration,
    required this.onToggleExpanded,
  });

  final List<PhotoItem> photos;
  final MetadataTemplate? selectedTemplate;
  final RenameConvention? selectedConvention;
  final bool isExpanded;
  final bool isCompact;
  final BoxDecoration decoration;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxRows = isCompact ? 5 : 8;
    final previewRows = photos.take(maxRows).toList(growable: false);
    final hiddenCount = photos.length - previewRows.length;
    final summary = photos.isEmpty
        ? 'Select photos to preview names'
        : selectedConvention == null
        ? '${photos.length} selected · choose a naming convention'
        : '${photos.length} selected · ${selectedConvention!.name}';

    return Container(
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.drive_file_rename_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rename Preview', style: theme.textTheme.titleSmall),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onToggleExpanded,
                icon: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                ),
                label: Text(isExpanded ? 'Hide' : 'Preview'),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: photos.isEmpty
                  ? Text(
                      'No selected photos yet.',
                      style: theme.textTheme.bodySmall,
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: isCompact ? 150 : 220,
                      ),
                      child: Scrollbar(
                        thumbVisibility: previewRows.length > 4,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount:
                              previewRows.length + (hiddenCount > 0 ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const Divider(height: 10),
                          itemBuilder: (context, index) {
                            if (index == previewRows.length) {
                              return Text(
                                '+ $hiddenCount more file(s)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              );
                            }

                            final photo = previewRows[index];
                            return _PreviewRow(
                              originalName: photo.fileName,
                              previewName: _previewName(photo, index),
                            );
                          },
                        ),
                      ),
                    ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  String _previewName(PhotoItem photo, int index) {
    final convention = selectedConvention;
    if (convention == null) {
      return photo.fileName;
    }

    final extension = p.extension(photo.fileName);
    final effectiveMetadata = _metadataAfterTemplate(photo.fullMetadata);
    final title =
        _firstMetadataValue(effectiveMetadata, const ['XMP.Title', 'Title']) ??
        photo.metadataSummary['Title'] ??
        p.basenameWithoutExtension(photo.fileName);

    return applyRenamePattern(
      pattern: convention.pattern,
      date: DateTime.now(),
      sequence: index + 1,
      title: title,
      metadata: effectiveMetadata,
      extension: extension,
    );
  }

  Map<String, String> _metadataAfterTemplate(Map<String, String> original) {
    final output = <String, String>{...original};
    final fields = selectedTemplate?.fields ?? const <String, String>{};
    for (final entry in fields.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        continue;
      }
      final key = entry.key.trim();
      final shortKey = key.contains('.') ? key.split('.').last : key;
      output[key] = value;
      output[shortKey] = value;
      output[key.replaceAll('.', ' ')] = value;
      if (shortKey.toLowerCase() == 'creator') {
        output['author'] = value;
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
    }
    return null;
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.originalName, required this.previewName});

  final String originalName;
  final String previewName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            originalName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.arrow_forward,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            previewName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplyActionBar extends StatelessWidget {
  const _ApplyActionBar({
    required this.canApply,
    required this.isApplying,
    required this.progress,
    required this.currentFile,
    required this.selectedCount,
    required this.onApply,
  });

  final bool canApply;
  final bool isApplying;
  final double progress;
  final String? currentFile;
  final int selectedCount;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isApplying) ...[
              LinearProgressIndicator(value: progress <= 0 ? null : progress),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    isApplying
                        ? currentFile ?? 'Applying changes...'
                        : selectedCount == 0
                        ? 'Select photos, a template, and a naming convention.'
                        : '$selectedCount photo(s) ready',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: canApply ? onApply : null,
                  icon: isApplying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add_check_circle_outlined),
                  label: Text(isApplying ? 'Applying...' : 'Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBrowserArea extends StatelessWidget {
  const _PhotoBrowserArea({
    required this.photos,
    required this.viewMode,
    required this.gridSize,
    required this.decoration,
    required this.onFocus,
    required this.onToggleSelection,
  });

  final List<PhotoItem> photos;
  final PhotoViewMode viewMode;
  final double gridSize;
  final BoxDecoration decoration;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onToggleSelection;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Center(child: Text('No photos selected yet.'));
    }

    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: viewMode == PhotoViewMode.list
            ? _buildList(context)
            : _buildGrid(context),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Scrollbar(
      thumbVisibility: photos.length > 6,
      child: ListView.separated(
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.zero,
        itemCount: photos.length,
        separatorBuilder: (context, index) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final photo = photos[index];
          return _PhotoListRow(
            photo: photo,
            onFocus: onFocus,
            onToggleSelection: onToggleSelection,
          );
        },
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            (constraints.maxWidth.isFinite ? constraints.maxWidth : gridSize)
                .clamp(1.0, double.infinity)
                .toDouble();
        final minimumTileSize = availableWidth < 140 ? availableWidth : 140.0;
        final tileSize = gridSize
            .clamp(minimumTileSize, availableWidth)
            .toDouble();
        return Scrollbar(
          thumbVisibility: photos.length > 6,
          child: GridView.builder(
            clipBehavior: Clip.hardEdge,
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: tileSize,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              return _PhotoGridCard(
                photo: photo,
                onFocus: onFocus,
                onToggleSelection: onToggleSelection,
              );
            },
          ),
        );
      },
    );
  }
}

class _PhotoGridCard extends StatelessWidget {
  const _PhotoGridCard({
    required this.photo,
    required this.onFocus,
    required this.onToggleSelection,
  });

  final PhotoItem photo;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlineColor = theme.colorScheme.outlineVariant;

    return MouseRegion(
      onEnter: (_) => onFocus(photo.path),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onToggleSelection(photo.path),
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: photo.isSelected
                    ? theme.colorScheme.primary
                    : outlineColor,
                width: photo.isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                    child: _PhotoPreview(path: photo.path, fit: BoxFit.cover),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    photo.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoListRow extends StatelessWidget {
  const _PhotoListRow({
    required this.photo,
    required this.onFocus,
    required this.onToggleSelection,
  });

  final PhotoItem photo;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlineColor = theme.colorScheme.outlineVariant;
    final isCompact = MediaQuery.sizeOf(context).width < 820;
    final thumbnailSize = isCompact ? 44.0 : 56.0;

    return MouseRegion(
      onEnter: (_) => onFocus(photo.path),
      child: Material(
        color: photo.isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onToggleSelection(photo.path),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: BoxConstraints(minHeight: isCompact ? 56 : 68),
            padding: EdgeInsets.all(isCompact ? 5 : 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: photo.isSelected
                    ? theme.colorScheme.primary
                    : outlineColor,
                width: photo.isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: thumbnailSize,
                  height: thumbnailSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _PhotoPreview(path: photo.path, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    photo.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: isCompact
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.bodyMedium,
                  ),
                ),
                if (photo.isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.path, required this.fit});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Image.file(
      File(path),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: theme.colorScheme.surface,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 28),
              const SizedBox(height: 6),
              Text(
                'Preview unavailable',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetadataSidePanel extends StatelessWidget {
  const _MetadataSidePanel({required this.photo});

  final PhotoItem? photo;

  @override
  Widget build(BuildContext context) {
    final currentPhoto = photo;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: currentPhoto == null
            ? const Center(
                child: Text('Hover or select a photo to view full metadata.'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Metadata',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentPhoto.fileName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _MetadataList(metadata: currentPhoto.fullMetadata),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MetadataList extends StatelessWidget {
  const _MetadataList({required this.metadata});

  final Map<String, String> metadata;

  @override
  Widget build(BuildContext context) {
    if (metadata.isEmpty) {
      return const Text('No metadata found.');
    }

    final sorted = metadata.entries.toList(growable: false)
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    final theme = Theme.of(context);

    return ListView.builder(
      itemCount: sorted.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final entry = sorted[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(entry.value, style: theme.textTheme.bodyMedium),
            ],
          ),
        );
      },
    );
  }
}

class _TemplateSelector extends StatelessWidget {
  const _TemplateSelector({
    required this.templates,
    required this.selectedTemplateId,
    required this.onSelected,
  });

  final List<MetadataTemplate> templates;
  final String? selectedTemplateId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('template-${selectedTemplateId ?? ''}'),
      initialValue: selectedTemplateId,
      isExpanded: true,
      isDense: true,
      menuMaxHeight: 320,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelText: 'Metadata template',
      ),
      items: templates
          .map(
            (template) => DropdownMenuItem<String>(
              value: template.id,
              child: Text(
                template.isFavorite ? '★ ${template.name}' : template.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: onSelected,
    );
  }
}

class _ConventionSelector extends StatelessWidget {
  const _ConventionSelector({
    required this.conventions,
    required this.selectedConventionId,
    required this.onSelected,
  });

  final List<RenameConvention> conventions;
  final String? selectedConventionId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('convention-${selectedConventionId ?? ''}'),
      initialValue: selectedConventionId,
      isExpanded: true,
      isDense: true,
      menuMaxHeight: 320,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelText: 'Naming convention',
      ),
      items: conventions
          .map(
            (convention) => DropdownMenuItem<String>(
              value: convention.id,
              child: Text(
                convention.isFavorite
                    ? '★ ${convention.name}'
                    : convention.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: onSelected,
    );
  }
}
