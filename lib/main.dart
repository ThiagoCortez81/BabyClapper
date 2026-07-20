import 'package:flutter/material.dart';

void main() {
  runApp(const BabyClapperApp());
}

/// Root widget for the BabyClapper app.
class BabyClapperApp extends StatelessWidget {
  /// Creates the BabyClapper app.
  const BabyClapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'BabyClapper',
      debugShowCheckedModeBanner: false,
      home: ColoredBox(color: Color(0xFF1B1B2F), child: SizedBox.expand()),
    );
  }
}
