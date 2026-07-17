import 'package:clipback_share_receiver/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders share receiver screen', (tester) async {
    await tester.pumpWidget(const ShareReceiverApp());

    expect(find.text('Clipback Share Receiver'), findsWidgets);
    expect(find.text('Send to Backend'), findsOneWidget);
    expect(find.text('Payload'), findsOneWidget);
  });
}
