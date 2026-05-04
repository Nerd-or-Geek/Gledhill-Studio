import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/main/presentation/main_screen.dart';
import 'features/settings/application/app_settings_controller.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/workflows/presentation/workflow_library_screen.dart';
import 'state/providers.dart';
import 'utils/external_links.dart';

class GledhillMetadataApp extends ConsumerWidget {
  const GledhillMetadataApp({super.key});

  void _forceDisableDebugOverlays() {
    assert(() {
      debugPaintSizeEnabled = false;
      debugPaintBaselinesEnabled = false;
      debugRepaintRainbowEnabled = false;
      debugPaintLayerBordersEnabled = false;
      debugPaintPointersEnabled = false;
      return true;
    }());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _forceDisableDebugOverlays();

    final settings = ref.watch(appSettingsControllerProvider);
    ref.watch(libraryCatalogControllerProvider);

    final lightTheme = ThemeData(
      colorScheme: _buildColorScheme(
        colorTheme: AppColorTheme.defaultBlue,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFF),
      useMaterial3: true,
    );
    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: _buildColorScheme(
        colorTheme: AppColorTheme.defaultBlue,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0B0F17),
      useMaterial3: true,
    );
    final navyTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF93B4FF),
        onPrimary: Color(0xFF0F1C33),
        secondary: Color(0xFFA8C1FF),
        onSecondary: Color(0xFF0E1A30),
        surface: Color(0xFF1A2940),
        onSurface: Color(0xFFE6EDFF),
        surfaceContainerHighest: Color(0xFF233754),
      ),
      scaffoldBackgroundColor: const Color(0xFF1B2B44),
      useMaterial3: true,
    );
    final charcoalTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD0D4DB),
        onPrimary: Color(0xFF2A2E34),
        secondary: Color(0xFFBBC0C8),
        onSecondary: Color(0xFF2B2F35),
        surface: Color(0xFF323841),
        onSurface: Color(0xFFF0F2F5),
        surfaceContainerHighest: Color(0xFF3D444E),
      ),
      scaffoldBackgroundColor: const Color(0xFF363C46),
      useMaterial3: true,
    );

    final selectedPreset = settings.themePreset;
    final selectedThemeMode = switch (selectedPreset) {
      AppThemePreset.system => ThemeMode.system,
      AppThemePreset.light => ThemeMode.light,
      AppThemePreset.dark => ThemeMode.dark,
      AppThemePreset.navyBlue => ThemeMode.dark,
      AppThemePreset.charcoalGray => ThemeMode.dark,
    };
    final selectedDarkTheme = switch (selectedPreset) {
      AppThemePreset.navyBlue => navyTheme,
      AppThemePreset.charcoalGray => charcoalTheme,
      _ => darkTheme,
    };

    return MaterialApp(
      title: 'Gledhill Metadata',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: selectedDarkTheme,
      themeMode: selectedThemeMode,
      home: const _RootScaffold(),
    );
  }

  ColorScheme _buildColorScheme({
    required AppColorTheme colorTheme,
    required Brightness brightness,
  }) {
    switch (colorTheme) {
      case AppColorTheme.defaultBlue:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B5BDB),
          brightness: brightness,
        );
      case AppColorTheme.navy:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D3557),
          brightness: brightness,
        );
      case AppColorTheme.charcoal:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF3A3F47),
          brightness: brightness,
        );
    }
  }
}

class _RootScaffold extends StatefulWidget {
  const _RootScaffold();

  @override
  State<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<_RootScaffold> {
  int _index = 0;

  static const _tabs = [
    NavigationDestination(
      icon: Icon(Icons.photo_library_outlined),
      label: 'Main',
    ),
    NavigationDestination(icon: Icon(Icons.hub_outlined), label: 'Workflows'),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      label: 'Settings',
    ),
  ];

  List<Widget> get _screens => [
    MainScreen(isActive: _index == 0),
    const WorkflowLibraryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_index].label),
        actions: [
          IconButton(
            tooltip: 'Open documentation',
            onPressed: () => openExternalUrl(context, documentationUrl),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        destinations: _tabs,
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}
