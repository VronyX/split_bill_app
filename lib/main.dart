import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/upload_screen.dart';

void main() {
  runApp(const SplitBillApp());
}

class SplitBillApp extends StatelessWidget {
  const SplitBillApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yuk Hitung-hitungan Kita',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const UploadScreen(),
    );
  }
}
