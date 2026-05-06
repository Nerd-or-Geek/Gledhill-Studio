import 'dart:ffi';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../features/settings/application/app_settings_controller.dart';
import 'metadata_tag_mapper.dart';

class MetadataWriteResult {
  const MetadataWriteResult({
    required this.successfulTagWrites,
    required this.warnings,
  });

  final int successfulTagWrites;
  final List<String> warnings;
}

class ExifToolService {
  final MetadataTagMapper _tagMapper = MetadataTagMapper();
  String? _cachedBinaryPath;

  Future<String> ensureBinaryReady() async {
    if (_cachedBinaryPath != null) {
      final cached = _cachedBinaryPath!;
      final looksLikePath = cached.contains(Platform.pathSeparator) || cached.contains('/') || cached.contains('\\');
      if (!looksLikePath || File(cached).existsSync()) {
        return cached;
      }
      _cachedBinaryPath = null;
    }

    // Tier 1: look next to our own executable (CMake puts it there for every build).
    final sideBySide = await _discoverSideBySideBinary();
    if (sideBySide != null) {
      _cachedBinaryPath = sideBySide;
      return sideBySide;
    }

    // Tier 2: find on system PATH (prioritize system installation).
    final systemBinary = await _discoverSystemExifToolBinary();
    if (systemBinary != null) {
      _cachedBinaryPath = systemBinary;
      return systemBinary;
    }

    // Tier 3: extract from Flutter assets into a persistent app-support folder
    // so the script and its support files stay side-by-side.
    try {
      final extracted = await _extractFromAssets();
      _cachedBinaryPath = extracted;
      return extracted;
    } catch (_) {
      // fall through to final error
    }

    throw StateError(
      'No usable ExifTool binary found. '
      'For Windows, provide either a standalone exiftool.exe OR the standard '
      'exiftool.exe + exiftool_files/ package under assets/tools/windows/, then rebuild. '
      'or install ExifTool on your system PATH.',
    );
  }

  /// Tier 1 – binary sitting next to our executable (copied there by CMake).
  Future<String?> _discoverSideBySideBinary() async {
    try {
      final execDir = File(Platform.resolvedExecutable).parent.path;
      final name = Platform.isWindows ? 'exiftool.exe' : 'exiftool';
      final candidate = File(p.join(execDir, name));
      if (await candidate.exists()) {
        final bytes = await candidate.readAsBytes();
        if (!_looksLikePlaceholderBinary(bytes) && await _isBinaryUsable(candidate.path)) {
          return candidate.path;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Tier 3 - unpack from Flutter asset bundle into a persistent support dir.
  Future<String> _extractFromAssets() async {
    final assetPath = _assetPathForCurrentPlatform();
    final executablePayload = await _loadAssetBytes(assetPath);

    if (_looksLikePlaceholderBinary(executablePayload)) {
      throw StateError('Bundled ExifTool binary is a placeholder.');
    }

    final supportDir = await getApplicationSupportDirectory();
    final toolDir = Directory(p.join(supportDir.path, 'tools', _toolCacheDirectoryName()));
    if (!await toolDir.exists()) {
      await toolDir.create(recursive: true);
    }

    final executableName = Platform.isWindows ? 'exiftool.exe' : 'exiftool';
    final executablePath = p.join(toolDir.path, executableName);
    await _extractAssetBundleDirectory(_assetDirectoryForCurrentPlatform(), toolDir);

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', executablePath]);
    }

    if (!await _isBinaryUsable(executablePath)) {
      throw StateError(
        Platform.isWindows
            ? 'Bundled ExifTool is not runnable. Provide either a standalone '
                'exiftool.exe, or ship exiftool_files/ next to exiftool.exe.'
            : 'Bundled ExifTool is not runnable on this platform.',
      );
    }

    return executablePath;
  }

  Future<void> _extractAssetBundleDirectory(String assetDirectory, Directory destinationDirectory) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where((asset) => asset == assetDirectory || asset.startsWith('$assetDirectory/'))
        .toList(growable: false);

    if (assets.isEmpty) {
      throw StateError('No bundled ExifTool assets found at $assetDirectory.');
    }

    for (final asset in assets) {
      final relativePath = asset == assetDirectory ? p.basename(asset) : asset.substring(assetDirectory.length + 1);
      if (relativePath.isEmpty) {
        continue;
      }

      final targetPath = p.joinAll([
        destinationDirectory.path,
        ...relativePath.split('/'),
      ]);
      final targetFile = File(targetPath);
      final payload = await _loadAssetBytes(asset);

      if (await _fileAlreadyMatches(targetFile, payload)) {
        continue;
      }

      final parent = targetFile.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await targetFile.writeAsBytes(payload, flush: true);
    }
  }

  Future<List<int>> _loadAssetBytes(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  }

  Future<bool> _fileAlreadyMatches(File file, List<int> payload) async {
    try {
      if (!await file.exists()) {
        return false;
      }

      return await file.length() == payload.length;
    } catch (_) {
      return false;
    }
  }

  Future<ProcessResult> run(List<String> args) async {
    final binary = await ensureBinaryReady();
    return Process.run(binary, args, workingDirectory: p.dirname(binary));
  }

  Future<bool> _isBinaryUsable(String binaryPath) async {
    try {
      final result = await Process.run(
        binaryPath,
        const ['-ver'],
        workingDirectory: p.dirname(binaryPath),
      );

      if (result.exitCode == 0) {
        return true;
      }

      if (Platform.isWindows && !_hasWindowsSupportFolder(binaryPath)) {
        return false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  bool _hasWindowsSupportFolder(String binaryPath) {
    if (!Platform.isWindows) {
      return true;
    }

    final dir = Directory(p.join(p.dirname(binaryPath), 'exiftool_files'));
    if (!dir.existsSync()) {
      return false;
    }

    try {
      return dir
          .listSync()
          .whereType<File>()
          .any((file) => p.basename(file.path).toLowerCase().contains('perl5'));
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> readMetadata(String filePath) async {
    final result = await run([
      '-j',
      '-G1',
      '-a',
      '-s',
      '-ee',
      '-api',
      'RequestAll=2',
      filePath,
    ]);
    if (result.exitCode != 0) {
      throw StateError('ExifTool read failed: ${result.stderr}');
    }

    final decoded = jsonDecode(result.stdout as String) as List<dynamic>;
    if (decoded.isEmpty) {
      return const {};
    }

    final first = decoded.first as Map<String, dynamic>;
    final metadata = <String, String>{};
    for (final entry in first.entries) {
      if (entry.key == 'SourceFile') {
        continue;
      }
      metadata[_normalizeGroupKey(entry.key)] = '${entry.value}';
    }
    return metadata;
  }

  Future<MetadataWriteResult> writeMetadata({
    required String filePath,
    required Map<String, String> templateFields,
    required MetadataMergeStrategy mergeStrategy,
  }) async {
    final warnings = <String>[];
    var successfulTagWrites = 0;

    if (mergeStrategy == MetadataMergeStrategy.replaceAll) {
      final clearResult = await _clearAllMetadata(filePath);
      if (!clearResult.didClear) {
        warnings.add(clearResult.message);
        return MetadataWriteResult(successfulTagWrites: 0, warnings: warnings);
      }
    }

    final tagAssignments = <String, String>{};
    for (final entry in templateFields.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        continue;
      }

      final tags = _tagMapper.tagsForField(entry.key).toSet().toList(growable: false);
      for (final tag in tags) {
        tagAssignments[tag] = value;
      }
    }

    for (final entry in tagAssignments.entries) {
      final tag = entry.key;
      final value = entry.value;
      if (_tagMapper.isListTag(tag)) {
        final values = value
            .split(',')
            .map((token) => token.trim())
            .where((token) => token.isNotEmpty)
            .toList(growable: false);

        if (values.isEmpty) {
          continue;
        }

        final listArgs = <String>['-overwrite_original_in_place', '-$tag='];
        for (final item in values) {
          listArgs.add('-$tag+=$item');
        }
        listArgs.add(filePath);

        final result = await run(listArgs);
        if (result.exitCode == 0) {
          successfulTagWrites++;
        } else {
          warnings.add('Failed writing $tag for $filePath: ${result.stderr}');
        }
      } else {
        final result = await run([
          '-overwrite_original_in_place',
          '-$tag=$value',
          filePath,
        ]);
        if (result.exitCode == 0) {
          successfulTagWrites++;
        } else {
          warnings.add('Failed writing $tag for $filePath: ${result.stderr}');
        }
      }
    }

    return MetadataWriteResult(successfulTagWrites: successfulTagWrites, warnings: warnings);
  }

  Future<_MetadataClearResult> _clearAllMetadata(String filePath) async {
    final clearArgs = [
      '-overwrite_original_in_place',
      '-all=',
      '-icc_profile:all=',
      '-xmp:all=',
      '-iptc:all=',
      '-exif:all=',
      filePath,
    ];

    final resetResult = await run(clearArgs);
    if (resetResult.exitCode != 0) {
      return _MetadataClearResult(
        didClear: false,
        message: 'Failed clearing existing metadata for $filePath: ${resetResult.stderr}',
      );
    }

    try {
      final remaining = await _readEmbeddedMetadata(filePath);
      final embeddedTags = remaining.keys.where((key) {
        final group = _metadataGroupName(key);
        if (group == null) {
          return false;
        }

        // Ignore synthetic/read-only groups that are computed by ExifTool and
        // are not embedded metadata chunks in the file.
        return !_syntheticReadGroups.contains(group);
      }).toList(growable: false);

      if (embeddedTags.isNotEmpty) {
        final first = embeddedTags.first;
        return _MetadataClearResult(
          didClear: false,
          message:
              'Metadata clear verification failed for $filePath. Still present: $first (${embeddedTags.length} tag(s) remain).',
        );
      }
    } catch (error) {
      return _MetadataClearResult(
        didClear: false,
        message: 'Metadata clear verification failed for $filePath: $error',
      );
    }

    return const _MetadataClearResult(didClear: true, message: '');
  }

  Future<Map<String, String>> _readEmbeddedMetadata(String filePath) async {
    final result = await run([
      '-j',
      '-G1',
      '-a',
      '-s',
      '-ee',
      '-api',
      'RequestAll=3',
      '-all:all',
      filePath,
    ]);
    if (result.exitCode != 0) {
      throw StateError('ExifTool embedded metadata read failed: ${result.stderr}');
    }

    final decoded = jsonDecode(result.stdout as String) as List<dynamic>;
    if (decoded.isEmpty) {
      return const {};
    }

    final first = decoded.first as Map<String, dynamic>;
    final metadata = <String, String>{};
    for (final entry in first.entries) {
      if (entry.key == 'SourceFile') {
        continue;
      }
      metadata[_normalizeGroupKey(entry.key)] = '${entry.value}';
    }
    return metadata;
  }

  String? _metadataGroupName(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final colonIndex = trimmed.indexOf(':');
    final spaceIndex = trimmed.indexOf(' ');

    if (colonIndex > 0 && (spaceIndex < 0 || colonIndex < spaceIndex)) {
      return trimmed.substring(0, colonIndex).toLowerCase();
    }

    if (spaceIndex > 0) {
      return trimmed.substring(0, spaceIndex).toLowerCase();
    }

    return null;
  }

  String _normalizeGroupKey(String raw) {
    final key = raw.trim();
    if (key.startsWith('[')) {
      final end = key.indexOf(']');
      if (end > 1 && end < key.length - 1) {
        final group = key.substring(1, end);
        final tag = key.substring(end + 1).trim();
        return '$group $tag';
      }
    }
    return key;
  }

  static const Set<String> _syntheticReadGroups = {
    'composite',
    'exiftool',
    'file',
    'system',
  };

  bool _looksLikePlaceholderBinary(List<int> bytes) {
    if (bytes.isEmpty) {
      return true;
    }
    final text = ascii.decode(bytes, allowInvalid: true);
    return text.contains('PLACEHOLDER_BINARY');
  }

  Future<String?> _discoverSystemExifToolBinary() async {
    final candidates = Platform.isWindows
        ? const ['exiftool.exe', 'exiftool', 'exiftool(-k).exe']
        : const ['exiftool'];

    for (final candidate in candidates) {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [candidate],
      );

      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        if (output.isNotEmpty) {
          final firstLine = output.split(RegExp(r'\r?\n')).first.trim();
          if (firstLine.isNotEmpty) {
            return firstLine;
          }
        }
      }
    }

    return null;
  }

  String _assetPathForCurrentPlatform() {
    final directory = _assetDirectoryForCurrentPlatform();
    if (Platform.isWindows) {
      return '$directory/exiftool.exe';
    }

    return '$directory/exiftool';
  }

  String _assetDirectoryForCurrentPlatform() {
    if (Platform.isWindows) {
      return 'assets/tools/windows';
    }

    if (Platform.isMacOS) {
      final abi = Abi.current();
      return abi == Abi.macosArm64 ? 'assets/tools/macos/arm64' : 'assets/tools/macos/x64';
    }

    if (Platform.isAndroid) {
      return 'assets/tools/android';
    }

    if (Platform.isIOS) {
      return 'assets/tools/ios';
    }

    throw UnsupportedError('Unsupported platform for ExifTool bundling');
  }

  String _toolCacheDirectoryName() {
    if (Platform.isWindows) {
      return 'windows';
    }

    if (Platform.isMacOS) {
      final abi = Abi.current();
      return abi == Abi.macosArm64 ? 'macos-arm64' : 'macos-x64';
    }

    if (Platform.isAndroid) {
      return 'android';
    }

    if (Platform.isIOS) {
      return 'ios';
    }

    return 'unknown';
  }
}

class _MetadataClearResult {
  const _MetadataClearResult({required this.didClear, required this.message});

  final bool didClear;
  final String message;
}
