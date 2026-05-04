import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/keyboard_shortcuts.dart';

enum MetadataMergeStrategy { replaceAll, mergeOverwrite }

enum AppColorTheme { defaultBlue, navy, charcoal }

enum AppThemePreset { system, light, dark, navyBlue, charcoalGray }

enum PhotoViewMode { list, grid }

class AppSettingsState {
  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.colorTheme = AppColorTheme.defaultBlue,
    this.themePreset = AppThemePreset.system,
    this.mergeStrategy = MetadataMergeStrategy.mergeOverwrite,
    this.photoViewMode = PhotoViewMode.grid,
    this.photoGridSize = 220,
    this.showApplyConfirmation = true,
    this.showFullErrorDetails = false,
    this.errorLog = const [],
    this.keyboardShortcuts = const {},
    this.defaultTemplateId,
    this.defaultConventionId,
    this.isLoaded = false,
  });

  final ThemeMode themeMode;
  final AppColorTheme colorTheme;
  final AppThemePreset themePreset;
  final MetadataMergeStrategy mergeStrategy;
  final PhotoViewMode photoViewMode;
  final double photoGridSize;
  final bool showApplyConfirmation;
  final bool showFullErrorDetails;
  final List<String> errorLog;
  final Map<PhotoShortcutCommand, KeyboardShortcutBinding> keyboardShortcuts;
  final String? defaultTemplateId;
  final String? defaultConventionId;
  final bool isLoaded;

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    AppColorTheme? colorTheme,
    AppThemePreset? themePreset,
    MetadataMergeStrategy? mergeStrategy,
    PhotoViewMode? photoViewMode,
    double? photoGridSize,
    bool? showApplyConfirmation,
    bool? showFullErrorDetails,
    List<String>? errorLog,
    Map<PhotoShortcutCommand, KeyboardShortcutBinding>? keyboardShortcuts,
    String? defaultTemplateId,
    String? defaultConventionId,
    bool? isLoaded,
    bool clearDefaultTemplate = false,
    bool clearDefaultConvention = false,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      colorTheme: colorTheme ?? this.colorTheme,
      themePreset: themePreset ?? this.themePreset,
      mergeStrategy: mergeStrategy ?? this.mergeStrategy,
      photoViewMode: photoViewMode ?? this.photoViewMode,
      photoGridSize: photoGridSize ?? this.photoGridSize,
      showApplyConfirmation:
          showApplyConfirmation ?? this.showApplyConfirmation,
      showFullErrorDetails: showFullErrorDetails ?? this.showFullErrorDetails,
      errorLog: errorLog ?? this.errorLog,
      keyboardShortcuts: keyboardShortcuts ?? this.keyboardShortcuts,
      defaultTemplateId: clearDefaultTemplate
          ? null
          : defaultTemplateId ?? this.defaultTemplateId,
      defaultConventionId: clearDefaultConvention
          ? null
          : defaultConventionId ?? this.defaultConventionId,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class AppSettingsController extends StateNotifier<AppSettingsState> {
  AppSettingsController() : super(const AppSettingsState()) {
    _load();
  }

  static const _themeModeKey = 'settings.theme_mode';
  static const _colorThemeKey = 'settings.color_theme';
  static const _themePresetKey = 'settings.theme_preset';
  static const _mergeStrategyKey = 'settings.merge_strategy';
  static const _photoViewModeKey = 'settings.photo_view_mode';
  static const _photoGridSizeKey = 'settings.photo_grid_size';
  static const _defaultTemplateIdKey = 'settings.default_template_id';
  static const _defaultConventionIdKey = 'settings.default_convention_id';
  static const _showApplyConfirmationKey = 'settings.show_apply_confirmation';
  static const _showFullErrorDetailsKey = 'settings.show_full_error_details';
  static const _errorLogKey = 'settings.error_log';
  static const _shortcutKeyPrefix = 'settings.shortcut.';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeRaw = prefs.getString(_themeModeKey);
    final colorThemeRaw = prefs.getString(_colorThemeKey);
    final presetRaw = prefs.getString(_themePresetKey);
    final mergeRaw = prefs.getString(_mergeStrategyKey);
    final photoViewModeRaw = prefs.getString(_photoViewModeKey);
    final photoGridSize = prefs.getDouble(_photoGridSizeKey);
    final defaultTemplateId = prefs.getString(_defaultTemplateIdKey);
    final defaultConventionId = prefs.getString(_defaultConventionIdKey);
    final showApplyConfirmation =
        prefs.getBool(_showApplyConfirmationKey) ?? true;
    final showFullErrorDetails =
        prefs.getBool(_showFullErrorDetailsKey) ?? false;
    final errorLog = prefs.getStringList(_errorLogKey) ?? const <String>[];
    final keyboardShortcuts = {
      for (final command in PhotoShortcutCommand.values)
        command:
            KeyboardShortcutBinding.tryParse(
              prefs.getString('$_shortcutKeyPrefix${command.name}'),
            ) ??
            KeyboardShortcutBinding.defaultFor(command),
    };

    final parsedThemeMode = _parseTheme(themeRaw);
    final parsedColorTheme = _parseColorTheme(colorThemeRaw);
    final parsedThemePreset = _parseThemePreset(
      presetRaw,
      fallbackThemeMode: parsedThemeMode,
      fallbackColorTheme: parsedColorTheme,
    );

    state = state.copyWith(
      themeMode: parsedThemeMode,
      colorTheme: parsedColorTheme,
      themePreset: parsedThemePreset,
      mergeStrategy: _parseMergeStrategy(mergeRaw),
      photoViewMode: _parsePhotoViewMode(photoViewModeRaw),
      photoGridSize: _normalizeGridSize(photoGridSize),
      showApplyConfirmation: showApplyConfirmation,
      showFullErrorDetails: showFullErrorDetails,
      errorLog: errorLog,
      keyboardShortcuts: keyboardShortcuts,
      defaultTemplateId: defaultTemplateId,
      defaultConventionId: defaultConventionId,
      isLoaded: true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future<void> setColorTheme(AppColorTheme theme) async {
    state = state.copyWith(colorTheme: theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorThemeKey, theme.name);
  }

  Future<void> setThemePreset(AppThemePreset preset) async {
    state = state.copyWith(themePreset: preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePresetKey, preset.name);
  }

  Future<void> setMergeStrategy(MetadataMergeStrategy strategy) async {
    state = state.copyWith(mergeStrategy: strategy);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mergeStrategyKey, strategy.name);
  }

  Future<void> setPhotoViewMode(PhotoViewMode mode) async {
    state = state.copyWith(photoViewMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_photoViewModeKey, mode.name);
  }

  Future<void> setPhotoGridSize(double size) async {
    final normalized = _normalizeGridSize(size);
    state = state.copyWith(photoGridSize: normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_photoGridSizeKey, normalized);
  }

  Future<void> setShowApplyConfirmation(bool value) async {
    state = state.copyWith(showApplyConfirmation: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showApplyConfirmationKey, value);
  }

  Future<void> setShowFullErrorDetails(bool value) async {
    state = state.copyWith(showFullErrorDetails: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showFullErrorDetailsKey, value);
  }

  Future<void> recordError(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final next = [
      '$timestamp  $message',
      ...state.errorLog,
    ].take(20).toList(growable: false);
    state = state.copyWith(errorLog: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_errorLogKey, next);
  }

  Future<void> recordErrors(Iterable<String> messages) async {
    final cleanMessages = messages
        .map((message) => message.trim())
        .where((message) => message.isNotEmpty)
        .toList(growable: false);
    if (cleanMessages.isEmpty) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final next = [
      for (final message in cleanMessages) '$timestamp  $message',
      ...state.errorLog,
    ].take(20).toList(growable: false);
    state = state.copyWith(errorLog: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_errorLogKey, next);
  }

  Future<void> clearErrorLog() async {
    state = state.copyWith(errorLog: const []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_errorLogKey);
  }

  Future<void> setKeyboardShortcut(
    PhotoShortcutCommand command,
    KeyboardShortcutBinding binding,
  ) async {
    final next = {...state.keyboardShortcuts, command: binding};
    state = state.copyWith(keyboardShortcuts: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_shortcutKeyPrefix${command.name}',
      binding.serialized,
    );
  }

  Future<void> resetKeyboardShortcuts() async {
    final next = {
      for (final command in PhotoShortcutCommand.values)
        command: KeyboardShortcutBinding.defaultFor(command),
    };
    state = state.copyWith(keyboardShortcuts: next);
    final prefs = await SharedPreferences.getInstance();
    for (final command in PhotoShortcutCommand.values) {
      await prefs.remove('$_shortcutKeyPrefix${command.name}');
    }
  }

  Future<void> setDefaultTemplateId(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      state = state.copyWith(clearDefaultTemplate: true);
      await prefs.remove(_defaultTemplateIdKey);
      return;
    }

    state = state.copyWith(defaultTemplateId: value);
    await prefs.setString(_defaultTemplateIdKey, value);
  }

  Future<void> setDefaultConventionId(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      state = state.copyWith(clearDefaultConvention: true);
      await prefs.remove(_defaultConventionIdKey);
      return;
    }

    state = state.copyWith(defaultConventionId: value);
    await prefs.setString(_defaultConventionIdKey, value);
  }

  Future<void> reconcileDefaults({
    required Set<String> validTemplateIds,
    required Set<String> validConventionIds,
  }) async {
    var clearTemplate = false;
    var clearConvention = false;

    final currentTemplateId = state.defaultTemplateId;
    if (currentTemplateId != null &&
        !validTemplateIds.contains(currentTemplateId)) {
      clearTemplate = true;
    }

    final currentConventionId = state.defaultConventionId;
    if (currentConventionId != null &&
        !validConventionIds.contains(currentConventionId)) {
      clearConvention = true;
    }

    if (!clearTemplate && !clearConvention) {
      return;
    }

    state = state.copyWith(
      clearDefaultTemplate: clearTemplate,
      clearDefaultConvention: clearConvention,
    );

    final prefs = await SharedPreferences.getInstance();
    if (clearTemplate) {
      await prefs.remove(_defaultTemplateIdKey);
    }
    if (clearConvention) {
      await prefs.remove(_defaultConventionIdKey);
    }
  }

  ThemeMode _parseTheme(String? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return ThemeMode.system;
  }

  MetadataMergeStrategy _parseMergeStrategy(String? value) {
    for (final strategy in MetadataMergeStrategy.values) {
      if (strategy.name == value) {
        return strategy;
      }
    }
    return MetadataMergeStrategy.mergeOverwrite;
  }

  PhotoViewMode _parsePhotoViewMode(String? value) {
    for (final mode in PhotoViewMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return PhotoViewMode.grid;
  }

  double _normalizeGridSize(double? value) {
    return (value ?? 220).clamp(140, 360).toDouble();
  }

  AppColorTheme _parseColorTheme(String? value) {
    for (final theme in AppColorTheme.values) {
      if (theme.name == value) {
        return theme;
      }
    }
    return AppColorTheme.defaultBlue;
  }

  AppThemePreset _parseThemePreset(
    String? value, {
    required ThemeMode fallbackThemeMode,
    required AppColorTheme fallbackColorTheme,
  }) {
    for (final preset in AppThemePreset.values) {
      if (preset.name == value) {
        return preset;
      }
    }

    if (fallbackColorTheme == AppColorTheme.navy) {
      return AppThemePreset.navyBlue;
    }
    if (fallbackColorTheme == AppColorTheme.charcoal) {
      return AppThemePreset.charcoalGray;
    }

    if (fallbackThemeMode == ThemeMode.light) {
      return AppThemePreset.light;
    }
    if (fallbackThemeMode == ThemeMode.dark) {
      return AppThemePreset.dark;
    }
    return AppThemePreset.system;
  }
}
