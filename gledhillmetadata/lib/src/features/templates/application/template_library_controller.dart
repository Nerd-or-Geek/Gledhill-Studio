import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/metadata_template.dart';
import '../../../models/template_folder_node.dart';
import '../../../services/template_storage_service.dart';

class TemplateLibraryState {
  const TemplateLibraryState({
    this.isLoading = true,
    this.folderTree,
    this.selectedFolderPath = '',
    this.templates = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  final bool isLoading;
  final TemplateFolderNode? folderTree;
  final String selectedFolderPath;
  final List<MetadataTemplate> templates;
  final String searchQuery;
  final String? errorMessage;

  List<MetadataTemplate> get filteredTemplates {
    final query = searchQuery.trim().toLowerCase();
    final base = [...templates]
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) {
          return a.isFavorite ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (query.isEmpty) {
      return base;
    }

    return base
        .where((template) => template.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  TemplateLibraryState copyWith({
    bool? isLoading,
    TemplateFolderNode? folderTree,
    String? selectedFolderPath,
    List<MetadataTemplate>? templates,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TemplateLibraryState(
      isLoading: isLoading ?? this.isLoading,
      folderTree: folderTree ?? this.folderTree,
      selectedFolderPath: selectedFolderPath ?? this.selectedFolderPath,
      templates: templates ?? this.templates,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class TemplateLibraryController extends StateNotifier<TemplateLibraryState> {
  TemplateLibraryController({required TemplateStorageService storageService})
    : _storageService = storageService,
      super(const TemplateLibraryState()) {
    refresh();
  }

  final TemplateStorageService _storageService;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tree = await _storageService.loadFolderTree();
      final templates = await _storageService.loadAllTemplates();
      state = state.copyWith(
        isLoading: false,
        folderTree: tree,
        selectedFolderPath: '',
        templates: templates,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load templates: $error',
      );
    }
  }

  Future<void> selectFolder(String relativePath) async {
    final templates = await _storageService.loadAllTemplates();
    state = state.copyWith(
      selectedFolderPath: '',
      templates: templates,
      clearError: true,
    );
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  Future<void> createFolder({
    required String parentRelativePath,
    required String folderName,
  }) async {
    await _storageService.createFolder(
      parentRelativePath: parentRelativePath,
      folderName: folderName,
    );
    await refresh();
  }

  Future<void> renameFolder({
    required String relativePath,
    required String newName,
  }) async {
    await _storageService.renameFolder(
      relativePath: relativePath,
      newName: newName,
    );
    await refresh();
  }

  Future<void> deleteFolder(String relativePath) async {
    await _storageService.deleteFolder(relativePath);
    await refresh();
  }

  Future<void> saveTemplate(
    MetadataTemplate template, {
    String? originalId,
  }) async {
    await _storageService.saveTemplate(
      relativeFolderPath: template.folderPath,
      template: template,
      originalId: originalId,
    );
    await refresh();
  }

  Future<void> deleteTemplate(MetadataTemplate template) async {
    await _storageService.deleteTemplate(
      relativeFolderPath: template.folderPath,
      templateId: template.id,
    );
    await refresh();
  }
}
