import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum PhotoShortcutCommand {
  selectAll,
  unselectAll,
  deleteSelected,
  apply,
  pickPhotos,
}

extension PhotoShortcutCommandLabel on PhotoShortcutCommand {
  String get label {
    switch (this) {
      case PhotoShortcutCommand.selectAll:
        return 'Select All';
      case PhotoShortcutCommand.unselectAll:
        return 'Unselect All';
      case PhotoShortcutCommand.deleteSelected:
        return 'Delete Selected';
      case PhotoShortcutCommand.apply:
        return 'Apply';
      case PhotoShortcutCommand.pickPhotos:
        return 'Pick Photos';
    }
  }
}

class KeyboardShortcutBinding {
  const KeyboardShortcutBinding({
    required this.key,
    this.control = false,
    this.meta = false,
    this.alt = false,
    this.shift = false,
  });

  final LogicalKeyboardKey key;
  final bool control;
  final bool meta;
  final bool alt;
  final bool shift;

  SingleActivator get activator => SingleActivator(
    key,
    control: control,
    meta: meta,
    alt: alt,
    shift: shift,
  );

  String get serialized =>
      '${key.keyId}|${control ? 1 : 0}|${meta ? 1 : 0}|${alt ? 1 : 0}|${shift ? 1 : 0}';

  String get displayLabel {
    final parts = <String>[
      if (meta) _isApple ? '⌘' : 'Meta',
      if (control) _isApple ? '⌃' : 'Ctrl',
      if (alt) _isApple ? '⌥' : 'Alt',
      if (shift) _isApple ? '⇧' : 'Shift',
      _keyLabel(key),
    ];
    return _isApple ? parts.join('') : parts.join('+');
  }

  static KeyboardShortcutBinding? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parts = value.split('|');
    if (parts.length != 5) {
      return null;
    }
    final keyId = int.tryParse(parts[0]);
    if (keyId == null) {
      return null;
    }
    final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
    if (key == null) {
      return null;
    }
    return KeyboardShortcutBinding(
      key: key,
      control: parts[1] == '1',
      meta: parts[2] == '1',
      alt: parts[3] == '1',
      shift: parts[4] == '1',
    );
  }

  static KeyboardShortcutBinding fromKeyEvent(KeyDownEvent event) {
    final hardware = HardwareKeyboard.instance;
    return KeyboardShortcutBinding(
      key: event.logicalKey,
      control:
          hardware.isControlPressed &&
          event.logicalKey != LogicalKeyboardKey.control,
      meta:
          hardware.isMetaPressed && event.logicalKey != LogicalKeyboardKey.meta,
      alt: hardware.isAltPressed && event.logicalKey != LogicalKeyboardKey.alt,
      shift:
          hardware.isShiftPressed &&
          event.logicalKey != LogicalKeyboardKey.shift,
    );
  }

  static KeyboardShortcutBinding defaultFor(PhotoShortcutCommand command) {
    switch (command) {
      case PhotoShortcutCommand.selectAll:
        return _primary(LogicalKeyboardKey.keyA);
      case PhotoShortcutCommand.unselectAll:
        return _primary(LogicalKeyboardKey.keyA, shift: true);
      case PhotoShortcutCommand.deleteSelected:
        return const KeyboardShortcutBinding(key: LogicalKeyboardKey.delete);
      case PhotoShortcutCommand.apply:
        return _primary(LogicalKeyboardKey.enter);
      case PhotoShortcutCommand.pickPhotos:
        return _primary(LogicalKeyboardKey.keyO);
    }
  }

  static KeyboardShortcutBinding _primary(
    LogicalKeyboardKey key, {
    bool shift = false,
  }) {
    return KeyboardShortcutBinding(
      key: key,
      meta: _isApple,
      control: !_isApple,
      shift: shift,
    );
  }

  static bool get _isApple => Platform.isMacOS || Platform.isIOS;

  static String _keyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.delete) {
      return _isApple ? '⌫' : 'Delete';
    }
    if (key == LogicalKeyboardKey.backspace) {
      return 'Backspace';
    }
    if (key == LogicalKeyboardKey.enter) {
      return _isApple ? '↩' : 'Enter';
    }
    if (key == LogicalKeyboardKey.space) {
      return 'Space';
    }
    final label = key.keyLabel.trim();
    if (label.isNotEmpty) {
      return label.toUpperCase();
    }
    return key.debugName ?? 'Key';
  }
}

bool isModifierOnlyKey(LogicalKeyboardKey key) {
  return [
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
  ].contains(key);
}
