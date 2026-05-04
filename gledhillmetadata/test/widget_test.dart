import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gledhill_metadata/src/app.dart';

void main() {
  testWidgets('Main screen scaffold renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GledhillMetadataApp()));
    await tester.pump();

    expect(find.text('Main'), findsWidgets);
    expect(find.text('Pick Photos'), findsOneWidget);
  });
}
