import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/rename_convention.dart';
import '../../../models/template_folder_node.dart';
import '../../../services/rename_convention_storage_service.dart';

class RenameLibraryState {
  const RenameLibraryState({
    this.isLoading = true,
    this.folderTree,
    this.selectedFolderPath = '',
    this.conventions = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  final bool isLoading;
  final TemplateFolderNode? folderTree;
  final String selectedFolderPath;
  final List<RenameConvention> conventions;
  final String searchQuery;
  final String? errorMessage;

  List<RenameConvention> get filteredConventions {
    final query = searchQuery.trim().toLowerCase();
    final base = [...conventions]
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
        .where((item) => item.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  RenameLibraryState copyWith({
    bool? isLoading,
    TemplateFolderNode? folderTree,
    String? selectedFolderPath,
    List<RenameConvention>? conventions,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RenameLibraryState(
      isLoading: isLoading ?? this.isLoading,
      folderTree: folderTree ?? this.folderTree,
      selectedFolderPath: selectedFolderPath ?? this.selectedFolderPath,
      conventions: conventions ?? this.conventions,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class RenameLibraryController extends StateNotifier<RenameLibraryState> {
  RenameLibraryController({
    required RenameConventionStorageService storageService,
  }) : _storageService = storageService,
       super(const RenameLibraryState()) {
    refresh();
  }

  final RenameConventionStorageService _storageService;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tree = await _storageService.loadFolderTree();
      final conventions = await _storageService.loadAllConventions();
      state = state.copyWith(
        isLoading: false,
        folderTree: tree,
        selectedFolderPath: '',
        conventions: conventions,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load conventions: $error',
      );
    }
  }

  Future<void> selectFolder(String relativePath) async {
    final conventions = await _storageService.loadAllConventions();
    state = state.copyWith(
      selectedFolderPath: '',
      conventions: conventions,
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

  Future<void> saveConvention(
    RenameConvention convention, {
    String? originalId,
  }) async {
    await _storageService.saveConvention(
      relativeFolderPath: convention.folderPath,
      convention: convention,
      originalId: originalId,
    );
    await refresh();
  }

  Future<void> deleteConvention(RenameConvention convention) async {
    await _storageService.deleteConvention(
      relativeFolderPath: convention.folderPath,
      conventionId: convention.id,
    );
    await refresh();
  }
}
