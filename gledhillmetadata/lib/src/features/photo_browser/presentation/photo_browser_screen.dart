import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';
import '../../batch/presentation/batch_apply_flow.dart';
import '../../metadata_editor/presentation/metadata_editor_panel.dart';
import 'photo_tile_card.dart';

class PhotoBrowserScreen extends ConsumerWidget {
  const PhotoBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(photoBrowserControllerProvider);
    final controller = ref.read(photoBrowserControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Browser'),
        actions: [
          TextButton.icon(
            onPressed: controller.pickPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Pick Photos'),
          ),
          IconButton(
            tooltip: 'Edit metadata',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: MetadataEditorPanel(selectedPhotoCount: state.selectedPhotos.length),
              ),
            ),
            icon: const Icon(Icons.edit_note_outlined),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          final gridCount = (constraints.maxWidth / 260).floor().clamp(1, 6);

          final photoGrid = DropTarget(
            onDragEntered: (_) => controller.setDragging(true),
            onDragExited: (_) => controller.setDragging(false),
            onDragDone: (details) {
              controller.setDragging(false);
              controller.addDroppedFiles(details.files.cast<dynamic>());
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.isDragging
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: state.isDragging ? 2.5 : 1,
                ),
              ),
              child: state.photos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Drop photos here or use Pick Photos',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text('Supports JPG, PNG, HEIC, TIFF, WEBP'),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        if (state.errorMessage != null)
                          MaterialBanner(
                            content: Text(state.errorMessage!),
                            actions: [
                              TextButton(
                                onPressed: controller.clearError,
                                child: const Text('Dismiss'),
                              ),
                            ],
                          ),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridCount,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: state.photos.length,
                            itemBuilder: (_, index) {
                              final photo = state.photos[index];
                              return PhotoTileCard(
                                photo: photo,
                                onTap: () => controller.toggleSelection(photo.path),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          );

          final metadataPanel = MetadataEditorPanel(selectedPhotoCount: state.selectedPhotos.length);

          if (isWide) {
            return Row(
              children: [
                Expanded(child: photoGrid),
                SizedBox(
                  width: 340,
                  child: metadataPanel,
                ),
              ],
            );
          }

          return photoGrid;
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.selectedPhotos.isEmpty
            ? null
            : () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BatchApplyFlow(selectedCount: state.selectedPhotos.length),
                ),
        icon: const Icon(Icons.playlist_add_check_circle_outlined),
        label: const Text('Batch Apply'),
      ),
    );
  }
}
