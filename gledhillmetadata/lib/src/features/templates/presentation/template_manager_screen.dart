import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/metadata_template.dart';
import '../../../state/providers.dart';

class TemplateManagerScreen extends ConsumerStatefulWidget {
  const TemplateManagerScreen({super.key});

  @override
  ConsumerState<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends ConsumerState<TemplateManagerScreen> {
  bool _loading = true;
  List<MetadataTemplate> _templates = const [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final service = ref.read(templateStorageServiceProvider);
    final templates = await service.loadTemplates();
    if (!mounted) {
      return;
    }
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  Future<void> _addTemplate() async {
    final nameController = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Template'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Template name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == null || created.isEmpty) {
      return;
    }

    final randomId = DateTime.now().millisecondsSinceEpoch + Random().nextInt(999);
    final next = [
      ..._templates,
      MetadataTemplate(
        id: '$randomId',
        name: created,
        fields: const {
          'Title': '',
          'Description': '',
          'Author': '',
          'Copyright': '',
          'Keywords': '',
          'Date Taken': '',
          'GPS': '',
        },
      ),
    ];

    await ref.read(templateStorageServiceProvider).saveTemplates(next);
    setState(() => _templates = next);
  }

  Future<void> _renameTemplate(MetadataTemplate template) async {
    final controller = TextEditingController(text: template.name);
    final renamed = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Template'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Template name'),
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

    if (renamed == null || renamed.isEmpty) {
      return;
    }

    final next = _templates
        .map((item) => item.id == template.id ? item.copyWith(name: renamed) : item)
        .toList(growable: false);
    await ref.read(templateStorageServiceProvider).saveTemplates(next);
    setState(() => _templates = next);
  }

  Future<void> _deleteTemplate(MetadataTemplate template) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('Delete "${template.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    final next = _templates.where((item) => item.id != template.id).toList(growable: false);
    await ref.read(templateStorageServiceProvider).saveTemplates(next);
    setState(() => _templates = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Template Manager')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTemplate,
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? const Center(child: Text('No templates yet. Create your first one.'))
              : ListView.separated(
                  itemCount: _templates.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return ListTile(
                      title: Text(template.name),
                      subtitle: Text('${template.fields.length} fields'),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            onPressed: () => _renameTemplate(template),
                            icon: const Icon(Icons.drive_file_rename_outline),
                          ),
                          IconButton(
                            onPressed: () => _deleteTemplate(template),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
