import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olivo_flutter/app.dart';

void main() {
  testWidgets('Olivo app builds', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OlivoApp()));
    await tester.pump();
    expect(find.textContaining('Olivo'), findsWidgets);
  });
}
