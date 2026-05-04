import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gledhill_metadata/src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  debugPaintSizeEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugRepaintRainbowEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugPaintPointersEnabled = false;

  runApp(const ProviderScope(child: GledhillMetadataApp()));
}
