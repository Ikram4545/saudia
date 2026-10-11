import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_driving_care/main.dart';

void main() {
  testWidgets('DrivingCareApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DrivingCareApp());
    expect(find.text('Driving Care'), findsOneWidget);
  });
}
