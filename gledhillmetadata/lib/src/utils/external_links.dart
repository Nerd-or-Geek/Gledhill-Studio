import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const documentationUrl =
    'https://nerd-or-geek.github.io/Gledhill-Metadata/docs.html';
const updatesUrl = 'https://nerd-or-geek.github.io/Gledhill-Metadata/#updates';
const issuesUrl = 'https://github.com/Nerd-or-Geek/Gledhill-Metadata/issues';
const githubSponsorsUrl = 'https://github.com/sponsors/Nerd-or-Geek';

Future<void> openExternalUrl(BuildContext context, String url) async {
  final command = Platform.isMacOS
      ? 'open'
      : Platform.isWindows
      ? 'rundll32'
      : 'xdg-open';
  final args = Platform.isWindows
      ? ['url.dll,FileProtocolHandler', url]
      : [url];

  try {
    final result = await Process.run(command, args);
    if (result.exitCode == 0) {
      return;
    }
  } catch (_) {}

  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Could not open browser. Link copied to clipboard.'),
    ),
  );
}
