import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_guillotine/src/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('shows the subscription dashboard', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SubscriptionGuillotineApp()),
    );
    await tester.pump();
    expect(find.text('Guillotine'), findsOneWidget);
    expect(find.byTooltip('Scan receipt'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
  });
}
