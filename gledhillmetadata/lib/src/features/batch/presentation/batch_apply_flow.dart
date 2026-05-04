import 'package:flutter/material.dart';

class BatchApplyFlow extends StatelessWidget {
  const BatchApplyFlow({
    super.key,
    required this.selectedCount,
  });

  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Batch Apply', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('Selected photos: $selectedCount'),
          const SizedBox(height: 12),
          const Text('Next step scaffold: choose template + rename policy, then apply with progress.'),
          const SizedBox(height: 16),
          const LinearProgressIndicator(value: null),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}
