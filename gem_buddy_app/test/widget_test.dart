import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gem/main.dart';
import 'package:gem/screens/main_scaffold.dart';

void main() {
  testWidgets('GEM Application smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: GemApp(),
      ),
    );

    // Verify MainScaffold is rendered
    expect(find.byType(MainScaffold), findsOneWidget);
  });
}
