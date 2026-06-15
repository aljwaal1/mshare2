import 'package:customers_services/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Customers Services starts', (tester) async {
    await tester.pumpWidget(const CustomersServicesApp());
    expect(find.text('دفتر العملاء والخدمات'), findsOneWidget);
  });
}
