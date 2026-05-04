import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gledhillstudio/src/app.dart';

void main() {
  testWidgets('Main screen scaffold renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GledhillStudioApp()));
    await tester.pump();

    expect(find.text('Main'), findsWidgets);
    expect(find.text('Pick Photos'), findsOneWidget);
  });
}
