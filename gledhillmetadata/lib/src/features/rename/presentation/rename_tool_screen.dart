import 'package:flutter/material.dart';

import '../../../utils/rename_pattern.dart';

class RenameToolScreen extends StatefulWidget {
  const RenameToolScreen({super.key});

  @override
  State<RenameToolScreen> createState() => _RenameToolScreenState();
}

class _RenameToolScreenState extends State<RenameToolScreen> {
  final TextEditingController _patternController =
      TextEditingController(text: '{year}-{month}-{sequence:3}-{title}');

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final preview = List.generate(5, (index) {
      return applyRenamePattern(
        pattern: _patternController.text,
        date: now,
        sequence: index + 1,
        title: 'Beach Sunset ${index + 1}',
        extension: '.jpg',
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Rename Tool')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _patternController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Pattern',
                border: OutlineInputBorder(),
                helperText: 'Tokens: {year}, {month}, {day}, {sequence:3}, {title}',
              ),
            ),
            const SizedBox(height: 16),
            Text('Live preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: Text(preview[index]),
                ),
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemCount: preview.length,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Apply Renames (with undo) — scaffolded'),
            ),
          ],
        ),
      ),
    );
  }
}
