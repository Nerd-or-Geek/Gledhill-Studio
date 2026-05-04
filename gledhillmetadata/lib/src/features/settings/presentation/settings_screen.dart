import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';
import '../../../utils/external_links.dart';
import '../../../utils/keyboard_shortcuts.dart';
import '../application/app_settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _appVersion = '1.6.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);
    final catalog = ref.watch(libraryCatalogControllerProvider);
    final photoBrowser = ref.watch(photoBrowserControllerProvider);
    final templateLibrary = ref.watch(templateLibraryControllerProvider);
    final renameLibrary = ref.watch(renameLibraryControllerProvider);

    final templates = catalog.templates;
    final conventions = catalog.conventions;
    final validTemplateIds = templates.map((item) => item.id).toSet();
    final validConventionIds = conventions.map((item) => item.id).toSet();

    final resolvedDefaultTemplateId =
        state.defaultTemplateId != null &&
            validTemplateIds.contains(state.defaultTemplateId)
        ? state.defaultTemplateId
        : null;
    final resolvedDefaultConventionId =
        state.defaultConventionId != null &&
            validConventionIds.contains(state.defaultConventionId)
        ? state.defaultConventionId
        : null;

    if (state.isLoaded && !catalog.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.reconcileDefaults(
          validTemplateIds: validTemplateIds,
          validConventionIds: validConventionIds,
        );
      });
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 860;
          final cardWidth = twoColumns
              ? (constraints.maxWidth - 48) / 2
              : constraints.maxWidth - 32;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _SettingsCard(
                      title: 'Workflow defaults',
                      icon: Icons.tune_outlined,
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'default-template-${resolvedDefaultTemplateId ?? ''}',
                          ),
                          initialValue: resolvedDefaultTemplateId ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Default template',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('None'),
                            ),
                            ...templates.map(
                              (template) => DropdownMenuItem<String>(
                                value: template.id,
                                child: Text(
                                  template.isFavorite
                                      ? '★ ${template.name}'
                                      : template.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              controller.setDefaultTemplateId(value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'default-convention-${resolvedDefaultConventionId ?? ''}',
                          ),
                          initialValue: resolvedDefaultConventionId ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Default naming convention',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('None'),
                            ),
                            ...conventions.map(
                              (convention) => DropdownMenuItem<String>(
                                value: convention.id,
                                child: Text(
                                  convention.isFavorite
                                      ? '★ ${convention.name}'
                                      : convention.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              controller.setDefaultConventionId(value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<MetadataMergeStrategy>(
                          key: ValueKey(
                            'merge-strategy-${state.mergeStrategy.name}',
                          ),
                          initialValue: state.mergeStrategy,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Metadata write mode',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: MetadataMergeStrategy.replaceAll,
                              child: Text('Replace all metadata'),
                            ),
                            DropdownMenuItem(
                              value: MetadataMergeStrategy.mergeOverwrite,
                              child: Text('Merge & overwrite'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              controller.setMergeStrategy(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SettingsCard(
                      title: 'Photo browser',
                      icon: Icons.photo_library_outlined,
                      children: [
                        SegmentedButton<PhotoViewMode>(
                          segments: const [
                            ButtonSegment<PhotoViewMode>(
                              value: PhotoViewMode.list,
                              icon: Icon(Icons.view_list_outlined),
                              label: Text('List'),
                            ),
                            ButtonSegment<PhotoViewMode>(
                              value: PhotoViewMode.grid,
                              icon: Icon(Icons.grid_view_outlined),
                              label: Text('Grid'),
                            ),
                          ],
                          selected: {state.photoViewMode},
                          onSelectionChanged: (selection) =>
                              controller.setPhotoViewMode(selection.first),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Grid thumbnail size: ${_gridSizeLabel(state.photoGridSize)}',
                        ),
                        Slider(
                          value: state.photoGridSize,
                          min: 140,
                          max: 360,
                          divisions: 4,
                          label: _gridSizeLabel(state.photoGridSize),
                          onChanged: controller.setPhotoGridSize,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SettingsCard(
                      title: 'Safety & errors',
                      icon: Icons.health_and_safety_outlined,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: state.showApplyConfirmation,
                          onChanged: controller.setShowApplyConfirmation,
                          title: const Text('Show Apply confirmation'),
                          subtitle: const Text(
                            'Warn before changing files, names, and metadata.',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: state.showFullErrorDetails,
                          onChanged: controller.setShowFullErrorDetails,
                          title: const Text('Show full errors immediately'),
                          subtitle: const Text(
                            'Default off. Quietly flags errors and saves details here.',
                          ),
                        ),
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Text('Last ${state.errorLog.length} error(s)'),
                          subtitle: const Text('The app keeps the last 20.'),
                          children: [
                            if (state.errorLog.isEmpty)
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('No errors logged yet.'),
                              )
                            else
                              SizedBox(
                                height: 220,
                                child: Scrollbar(
                                  thumbVisibility: state.errorLog.length > 4,
                                  child: ListView.separated(
                                    itemCount: state.errorLog.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) => ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: SelectableText(
                                        state.errorLog[index],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: state.errorLog.isEmpty
                                      ? null
                                      : () => _copyErrorLog(context, state),
                                  icon: const Icon(Icons.copy_all_outlined),
                                  label: const Text('Copy Error Log'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: state.errorLog.isEmpty
                                      ? null
                                      : controller.clearErrorLog,
                                  icon: const Icon(Icons.clear_all_outlined),
                                  label: const Text('Clear Log'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SettingsCard(
                      title: 'Keyboard shortcuts',
                      icon: Icons.keyboard_outlined,
                      children: [
                        for (final command in PhotoShortcutCommand.values)
                          _ShortcutRow(
                            command: command,
                            binding:
                                state.keyboardShortcuts[command] ??
                                KeyboardShortcutBinding.defaultFor(command),
                            onChange: () =>
                                _editShortcut(context, controller, command),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: controller.resetKeyboardShortcuts,
                            icon: const Icon(Icons.restore_outlined),
                            label: const Text('Reset Defaults'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SettingsCard(
                      title: 'Appearance',
                      icon: Icons.palette_outlined,
                      children: [
                        DropdownButtonFormField<AppThemePreset>(
                          key: ValueKey(
                            'theme-preset-${state.themePreset.name}',
                          ),
                          initialValue: state.themePreset,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Theme preset',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: AppThemePreset.system,
                              child: Text('System theme'),
                            ),
                            DropdownMenuItem(
                              value: AppThemePreset.light,
                              child: Text('Light theme'),
                            ),
                            DropdownMenuItem(
                              value: AppThemePreset.dark,
                              child: Text('Dark theme'),
                            ),
                            DropdownMenuItem(
                              value: AppThemePreset.navyBlue,
                              child: Text('Navy blue theme'),
                            ),
                            DropdownMenuItem(
                              value: AppThemePreset.charcoalGray,
                              child: Text('Charcoal gray theme'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              controller.setThemePreset(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SettingsCard(
                      title: 'Support',
                      icon: Icons.support_agent_outlined,
                      children: [
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Gledhill Metadata'),
                          subtitle: Text('Version $_appVersion'),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  openExternalUrl(context, updatesUrl),
                              icon: const Icon(
                                Icons.system_update_alt_outlined,
                              ),
                              label: const Text('Check for Updates'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _copyBugReportDetails(
                                context: context,
                                settings: state,
                                templateCount: templates.length,
                                conventionCount: conventions.length,
                                catalogError: catalog.errorMessage,
                                photoBrowserError: photoBrowser.errorMessage,
                                templateLibraryError:
                                    templateLibrary.errorMessage,
                                renameLibraryError: renameLibrary.errorMessage,
                              ),
                              icon: const Icon(Icons.bug_report_outlined),
                              label: const Text('Copy Bug Details'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  openExternalUrl(context, issuesUrl),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Report Issue'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _copyBugReportDetails({
    required BuildContext context,
    required AppSettingsState settings,
    required int templateCount,
    required int conventionCount,
    required String? catalogError,
    required String? photoBrowserError,
    required String? templateLibraryError,
    required String? renameLibraryError,
  }) async {
    final details = [
      'Gledhill Metadata bug report',
      'Version: $_appVersion',
      'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'Dart executable: ${Platform.resolvedExecutable}',
      'Settings loaded: ${settings.isLoaded}',
      'Theme preset: ${settings.themePreset.name}',
      'Merge strategy: ${settings.mergeStrategy.name}',
      'Apply confirmation: ${settings.showApplyConfirmation}',
      'Show full errors: ${settings.showFullErrorDetails}',
      'Default template ID: ${settings.defaultTemplateId ?? '(none)'}',
      'Default naming convention ID: ${settings.defaultConventionId ?? '(none)'}',
      'Template count: $templateCount',
      'Naming convention count: $conventionCount',
      'Catalog error: ${catalogError ?? '(none)'}',
      'Photo browser error: ${photoBrowserError ?? '(none)'}',
      'Template library error: ${templateLibraryError ?? '(none)'}',
      'Rename library error: ${renameLibraryError ?? '(none)'}',
      'Recent errors:',
      if (settings.errorLog.isEmpty) '(none)' else ...settings.errorLog,
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: details));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bug report details copied to clipboard.')),
    );
  }

  Future<void> _editShortcut(
    BuildContext context,
    AppSettingsController controller,
    PhotoShortcutCommand command,
  ) async {
    final binding = await showDialog<KeyboardShortcutBinding>(
      context: context,
      builder: (context) => _ShortcutCaptureDialog(command: command),
    );
    if (binding == null) {
      return;
    }
    await controller.setKeyboardShortcut(command, binding);
  }

  Future<void> _copyErrorLog(
    BuildContext context,
    AppSettingsState settings,
  ) async {
    final details = settings.errorLog.isEmpty
        ? 'No errors logged.'
        : settings.errorLog.join('\n');
    await Clipboard.setData(ClipboardData(text: details));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error log copied to clipboard.')),
    );
  }

  String _gridSizeLabel(double value) {
    final labels = ['Small', 'Small+', 'Medium', 'Large-', 'Large'];
    final index = ((value.clamp(140, 360) - 140) / 55)
        .round()
        .clamp(0, 4)
        .toInt();
    return labels[index];
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
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

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.command,
    required this.binding,
    required this.onChange,
  });

  final PhotoShortcutCommand command;
  final KeyboardShortcutBinding binding;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(command.label),
      subtitle: Text(binding.displayLabel),
      trailing: OutlinedButton(
        onPressed: onChange,
        child: const Text('Change'),
      ),
    );
  }
}

class _ShortcutCaptureDialog extends StatefulWidget {
  const _ShortcutCaptureDialog({required this.command});

  final PhotoShortcutCommand command;

  @override
  State<_ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState extends State<_ShortcutCaptureDialog> {
  late final FocusNode _focusNode;
  KeyboardShortcutBinding? _preview;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Set ${widget.command.label} Shortcut'),
      content: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent || isModifierOnlyKey(event.logicalKey)) {
            return;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return;
          }
          final binding = KeyboardShortcutBinding.fromKeyEvent(event);
          setState(() => _preview = binding);
          Navigator.of(context).pop(binding);
        },
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_command_key_outlined,
                size: 42,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Press the key combination you want to use.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _preview?.displayLabel ?? 'Waiting for shortcut…',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Esc cancels. Shortcuts work in the Main pictures section.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
