import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/main.dart';

void main() {
  testWidgets('beranda menampilkan pilihan sumber struk', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_text_recognizer'), (_) async => null);

    await tester.pumpWidget(const SplitBillApp());

    expect(find.text('Foto struk'), findsWidgets);
    expect(find.text('Pilih dari galeri'), findsOneWidget);
    expect(find.text('Isi manual tanpa foto'), findsOneWidget);
  });
}
