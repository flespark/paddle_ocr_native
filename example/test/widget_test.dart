import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paddle_ocr_native_example/main.dart';

void main() {
  testWidgets('renders both OCR entry points', (tester) async {
    await tester.pumpWidget(const PaddleOcrExampleApp());

    expect(find.text('Paddle OCR Native'), findsOneWidget);
    expect(find.byKey(const ValueKey('run_sample_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick_image_button')), findsOneWidget);
    expect(
      find.text('Select an image or run the bundled sample.'),
      findsOneWidget,
    );
  });
}
