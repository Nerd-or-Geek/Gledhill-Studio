import 'package:flutter/material.dart';

class MetadataEditorPanel extends StatelessWidget {
  const MetadataEditorPanel({
    super.key,
    required this.selectedPhotoCount,
  });

  final int selectedPhotoCount;

  @override
  Widget build(BuildContext context) {
    final title = selectedPhotoCount <= 1
        ? 'Metadata Editor'
        : 'Metadata Editor ($selectedPhotoCount photos selected)';

    final fields = <String>[
      'Title',
      'Description',
      'Copyright',
      'Author',
      'Keywords (comma separated)',
      'Date Taken',
      'GPS Location',
    ];

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'Scaffolded editor fields. Wiring to ExifTool write flow comes next.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final field in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: field,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
