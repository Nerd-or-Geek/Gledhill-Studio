import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../models/photo_item.dart';
import '../../../services/exif_reader_service.dart';
import '../../../services/file_selection_service.dart';

class PhotoBrowserState {
  const PhotoBrowserState({
    this.photos = const [],
    this.isLoading = false,
    this.isDragging = false,
    this.focusedPhotoPath,
    this.errorMessage,
  });

  final List<PhotoItem> photos;
  final bool isLoading;
  final bool isDragging;
  final String? focusedPhotoPath;
  final String? errorMessage;

  List<PhotoItem> get selectedPhotos =>
      photos.where((p) => p.isSelected).toList(growable: false);

  PhotoBrowserState copyWith({
    List<PhotoItem>? photos,
    bool? isLoading,
    bool? isDragging,
    String? focusedPhotoPath,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PhotoBrowserState(
      photos: photos ?? this.photos,
      isLoading: isLoading ?? this.isLoading,
      isDragging: isDragging ?? this.isDragging,
      focusedPhotoPath: focusedPhotoPath ?? this.focusedPhotoPath,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class PhotoBrowserController extends StateNotifier<PhotoBrowserState> {
  PhotoBrowserController({
    required FileSelectionService fileSelectionService,
    required ExifReaderService exifReaderService,
    required Future<void> Function(String message) onError,
  }) : _fileSelectionService = fileSelectionService,
       _exifReaderService = exifReaderService,
       _onError = onError,
       super(const PhotoBrowserState());

  final FileSelectionService _fileSelectionService;
  final ExifReaderService _exifReaderService;
  final Future<void> Function(String message) _onError;

  Future<void> pickPhotos() async {
    try {
      final selected = await _fileSelectionService.pickPhotoPaths();
      if (selected.isEmpty) {
        return;
      }
      await addPaths(selected);
    } catch (error) {
      await _setError('Could not open photo picker: $error');
    }
  }

  Future<void> addDroppedFiles(List<dynamic> files) async {
    final paths = files
        .map((f) {
          if (f == null) {
            return null;
          }
          final dynamic value = f;
          return value.path as String?;
        })
        .whereType<String>()
        .where(_isSupportedImage)
        .toList(growable: false);
    if (paths.isEmpty) {
      return;
    }
    await addPaths(paths);
  }

  Future<void> addPaths(List<String> rawPaths) async {
    final existing = state.photos.map((p) => p.path).toSet();
    final paths = rawPaths
        .where(_isSupportedImage)
        .where((path) => !existing.contains(path))
        .toList(growable: false);

    if (paths.isEmpty) {
      return;
    }

    final newItems = paths
        .map(
          (path) => PhotoItem(
            path: path,
            fileName: p.basename(path),
            metadataSummary: const {'Status': 'Reading metadata...'},
          ),
        )
        .toList(growable: false);

    state = state.copyWith(
      photos: [...state.photos, ...newItems],
      isLoading: true,
      focusedPhotoPath: state.focusedPhotoPath ?? newItems.first.path,
      clearError: true,
    );

    for (final path in paths) {
      await _loadMetadataForPath(path);
    }

    state = state.copyWith(isLoading: false);
  }

  Future<void> replacePhotos(List<String> paths) async {
    state = const PhotoBrowserState();
    if (paths.isEmpty) {
      return;
    }
    await addPaths(paths);
  }

  Future<void> refreshAllMetadata() async {
    final paths = state.photos
        .map((photo) => photo.path)
        .toList(growable: false);
    if (paths.isEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true);
    for (final path in paths) {
      await _loadMetadataForPath(path);
    }
    state = state.copyWith(isLoading: false);
  }

  void applyPathUpdates(Map<String, String> pathMappings) {
    if (pathMappings.isEmpty) {
      return;
    }

    final updated = state.photos
        .map((photo) {
          final nextPath = pathMappings[photo.path] ?? photo.path;
          if (nextPath == photo.path) {
            return photo;
          }
          return photo.copyWith(path: nextPath, fileName: p.basename(nextPath));
        })
        .toList(growable: false);

    final focused = state.focusedPhotoPath;
    final nextFocused = focused == null
        ? null
        : (pathMappings[focused] ?? focused);
    state = state.copyWith(photos: updated, focusedPhotoPath: nextFocused);
  }

  Future<void> _loadMetadataForPath(String path) async {
    try {
      final fullMetadata = await _exifReaderService.readAllMetadata(path);
      final summary = _exifReaderService.buildSummary(fullMetadata);
      final updated = state.photos
          .map(
            (photo) => photo.path == path
                ? photo.copyWith(
                    metadataSummary: summary,
                    fullMetadata: fullMetadata,
                  )
                : photo,
          )
          .toList(growable: false);
      state = state.copyWith(photos: updated, clearError: true);
    } catch (error) {
      await _setError(
        'Failed to read metadata for ${p.basename(path)}: $error',
      );
    }
  }

  void setDragging(bool value) {
    state = state.copyWith(isDragging: value);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void toggleSelection(String path) {
    final updated = state.photos
        .map(
          (photo) => photo.path == path
              ? photo.copyWith(isSelected: !photo.isSelected)
              : photo,
        )
        .toList(growable: false);
    state = state.copyWith(photos: updated, focusedPhotoPath: path);
  }

  void selectAllPhotos() {
    if (state.photos.isEmpty) {
      return;
    }

    final updated = state.photos
        .map((photo) => photo.copyWith(isSelected: true))
        .toList(growable: false);
    state = state.copyWith(
      photos: updated,
      focusedPhotoPath: state.focusedPhotoPath ?? state.photos.first.path,
    );
  }

  void clearSelection() {
    if (state.photos.isEmpty) {
      return;
    }

    final updated = state.photos
        .map((photo) => photo.copyWith(isSelected: false))
        .toList(growable: false);
    state = state.copyWith(photos: updated);
  }

  void removeSelectedPhotos() {
    final remaining = state.photos
        .where((photo) => !photo.isSelected)
        .toList(growable: false);

    String? nextFocused = state.focusedPhotoPath;
    if (nextFocused != null &&
        remaining.every((photo) => photo.path != nextFocused)) {
      nextFocused = remaining.isEmpty ? null : remaining.first.path;
    }

    state = state.copyWith(photos: remaining, focusedPhotoPath: nextFocused);
  }

  void focusPhoto(String path) {
    state = state.copyWith(focusedPhotoPath: path);
  }

  Future<void> _setError(String message) async {
    state = state.copyWith(errorMessage: message);
    await _onError(message);
  }

  bool _isSupportedImage(String path) {
    final extension = p.extension(path).toLowerCase();
    return const {
          '.jpg',
          '.jpeg',
          '.png',
          '.heic',
          '.tif',
          '.tiff',
          '.webp',
        }.contains(extension) &&
        File(path).existsSync();
  }
}
