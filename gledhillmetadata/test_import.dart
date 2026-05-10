import 'dart:convert';
import 'dart:io';
import 'package:gledhill_metadata/src/services/import_export_service.dart';

void main(List<String> args) async {
  final service = ImportExportService();
  final path = args.isNotEmpty
      ? args[0]
      : '/Users/jgledhil/Documents/GitHub/Gledhill-Studio/Templates New/Metadata/131 AE.json';
  final jsonString = await File(path).readAsString();
  final rawJson = jsonDecode(jsonString) as Map<String, dynamic>;
  print('type: ${rawJson['type']}');
  print('fields exists: ${rawJson.containsKey('fields')}');
  final kind = service.detectKind(rawJson);
  print('kind: $kind');
  final template = service.toTemplate(rawJson);
  print('name: ${template.name}, favorite: ${template.isFavorite}, fields: ${template.fields.keys}');
}
