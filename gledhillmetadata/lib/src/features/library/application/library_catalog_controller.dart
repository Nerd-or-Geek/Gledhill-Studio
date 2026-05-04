import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/metadata_template.dart';
import '../../../models/rename_convention.dart';
import '../../../services/rename_convention_storage_service.dart';
import '../../../services/template_storage_service.dart';

class LibraryCatalogState {
  const LibraryCatalogState({
    this.isLoading = true,
    this.templates = const [],
    this.conventions = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final List<MetadataTemplate> templates;
  final List<RenameConvention> conventions;
  final String? errorMessage;

  LibraryCatalogState copyWith({
    bool? isLoading,
    List<MetadataTemplate>? templates,
    List<RenameConvention>? conventions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LibraryCatalogState(
      isLoading: isLoading ?? this.isLoading,
      templates: templates ?? this.templates,
      conventions: conventions ?? this.conventions,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class LibraryCatalogController extends StateNotifier<LibraryCatalogState> {
  LibraryCatalogController({
    required TemplateStorageService templateStorageService,
    required RenameConventionStorageService renameStorageService,
  })  : _templateStorageService = templateStorageService,
        _renameStorageService = renameStorageService,
        super(const LibraryCatalogState()) {
    refresh();
  }

  final TemplateStorageService _templateStorageService;
  final RenameConventionStorageService _renameStorageService;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final templates = await _templateStorageService.loadAllTemplates();
      final conventions = await _renameStorageService.loadAllConventions();
      state = state.copyWith(
        isLoading: false,
        templates: templates,
        conventions: conventions,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to preload data: $error');
    }
  }
}
