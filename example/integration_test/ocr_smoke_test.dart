import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paddle_ocr_native_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recognizes the bundled sample', (tester) async {
    await tester.pumpWidget(const PaddleOcrExampleApp());
    await tester.tap(find.byKey(const ValueKey('run_sample_button')));
    await tester.pump();

    for (var attempt = 0; attempt < 1200; attempt++) {
      if (find.byKey(const ValueKey('ocr_result_list')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('ocr_error')).evaluate().isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    final resultList = find.byKey(const ValueKey('ocr_result_list'));
    expect(find.byKey(const ValueKey('ocr_error')), findsNothing);
    expect(resultList, findsOneWidget);
    expect(
      find.descendant(of: resultList, matching: find.byType(ListTile)),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('ocr_metrics')), findsOneWidget);
  });
}
