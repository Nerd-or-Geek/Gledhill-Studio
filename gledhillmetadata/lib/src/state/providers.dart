import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/library/application/library_catalog_controller.dart';
import '../features/rename/application/rename_library_controller.dart';
import '../features/settings/application/app_settings_controller.dart';
import '../features/photo_browser/application/photo_browser_controller.dart';
import '../features/templates/application/template_library_controller.dart';
import '../services/batch_apply_service.dart';
import '../services/exif_reader_service.dart';
import '../services/exiftool_service.dart';
import '../services/file_selection_service.dart';
import '../services/import_export_service.dart';
import '../services/rename_convention_storage_service.dart';
import '../services/template_storage_service.dart';

final fileSelectionServiceProvider = Provider<FileSelectionService>((ref) {
  return FileSelectionService();
});

final exifReaderServiceProvider = Provider<ExifReaderService>((ref) {
  return ExifReaderService(exifToolService: ref.read(exifToolServiceProvider));
});

final templateStorageServiceProvider = Provider<TemplateStorageService>((ref) {
  return TemplateStorageService();
});

final renameConventionStorageServiceProvider =
    Provider<RenameConventionStorageService>((ref) {
      return RenameConventionStorageService();
    });

final exifToolServiceProvider = Provider<ExifToolService>((ref) {
  return ExifToolService();
});

final batchApplyServiceProvider = Provider<BatchApplyService>((ref) {
  return BatchApplyService(exifToolService: ref.read(exifToolServiceProvider));
});

final importExportServiceProvider = Provider<ImportExportService>((ref) {
  return ImportExportService();
});

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsState>((ref) {
      return AppSettingsController();
    });

final photoBrowserControllerProvider =
    StateNotifierProvider<PhotoBrowserController, PhotoBrowserState>((ref) {
      return PhotoBrowserController(
        fileSelectionService: ref.read(fileSelectionServiceProvider),
        exifReaderService: ref.read(exifReaderServiceProvider),
        onError: ref.read(appSettingsControllerProvider.notifier).recordError,
      );
    });

final templateLibraryControllerProvider =
    StateNotifierProvider<TemplateLibraryController, TemplateLibraryState>((
      ref,
    ) {
      return TemplateLibraryController(
        storageService: ref.read(templateStorageServiceProvider),
      );
    });

final renameLibraryControllerProvider =
    StateNotifierProvider<RenameLibraryController, RenameLibraryState>((ref) {
      return RenameLibraryController(
        storageService: ref.read(renameConventionStorageServiceProvider),
      );
    });

final libraryCatalogControllerProvider =
    StateNotifierProvider<LibraryCatalogController, LibraryCatalogState>((ref) {
      return LibraryCatalogController(
        templateStorageService: ref.read(templateStorageServiceProvider),
        renameStorageService: ref.read(renameConventionStorageServiceProvider),
      );
    });
